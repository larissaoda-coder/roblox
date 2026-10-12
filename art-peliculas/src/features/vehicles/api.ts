import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ensureAffected } from '@/lib/errors'
import { fileExtension, prepareImage, randomName, removeMedia, uploadMedia } from '@/lib/storage'
import type { Film, GlassMap, GlassMasks, ImageView, Vehicle, VehicleCategory, VehicleFilm, VehicleImage, VehicleWithMedia } from '@/types/domain'

export const vehicleKeys = {
  all: ['vehicles'] as const,
  list: () => ['vehicles', 'list'] as const,
  detail: (id: string) => ['vehicles', 'detail', id] as const,
  films: (id: string) => ['vehicles', 'films', id] as const,
}

const LIST_SELECT = '*, vehicle_images(id, vehicle_id, storage_path, view, source_credit, glass_masks, width, height, is_primary, created_at, updated_at)'

export function useVehicles() {
  return useQuery({
    queryKey: vehicleKeys.list(),
    queryFn: async () => {
      const { data, error } = await supabase.from('vehicles').select(LIST_SELECT).order('brand').order('model').order('year_start')
      if (error) throw error
      return data as VehicleWithMedia[]
    },
  })
}

export function useVehicle(id: string | undefined) {
  return useQuery({
    queryKey: vehicleKeys.detail(id ?? ''),
    enabled: Boolean(id),
    queryFn: async () => {
      const { data, error } = await supabase.from('vehicles').select(LIST_SELECT).eq('id', id!).maybeSingle()
      if (error) throw error
      return data as VehicleWithMedia | null
    },
  })
}

export interface VehicleFilmRow extends VehicleFilm {
  film: Film
}

export function useVehicleFilms(vehicleId: string | undefined) {
  return useQuery({
    queryKey: vehicleKeys.films(vehicleId ?? ''),
    enabled: Boolean(vehicleId),
    queryFn: async () => {
      const { data, error } = await supabase.from('vehicle_films').select('*, film:films(*)').eq('vehicle_id', vehicleId!)
      if (error) throw error
      return (data as VehicleFilmRow[]).sort((a, b) => b.film.vlt_percent - a.film.vlt_percent)
    },
  })
}

export interface VehicleInput {
  brand: string
  model: string
  generation: string
  year_start: number | null
  year_end: number | null
  category: VehicleCategory
  doors: number | null
  notes: string
  active: boolean
}

function useInvalidate() {
  const qc = useQueryClient()
  return (id?: string) => {
    void qc.invalidateQueries({ queryKey: vehicleKeys.list() })
    void qc.invalidateQueries({ queryKey: ['dashboard'] })
    if (id) void qc.invalidateQueries({ queryKey: vehicleKeys.detail(id) })
  }
}

export function useSaveVehicle() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async ({ id, input }: { id?: string; input: VehicleInput }) => {
      if (id) {
        const { data, error } = await supabase.from('vehicles').update(input).eq('id', id).select()
        if (error) throw error
        return ensureAffected(data)[0] as Vehicle
      }
      const { data, error } = await supabase.from('vehicles').insert(input).select().single()
      if (error) throw error
      return data as Vehicle
    },
    onSuccess: (v) => invalidate(v.id),
  })
}

export function useDeleteVehicle() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async (vehicle: VehicleWithMedia) => {
      const { data, error } = await supabase.from('vehicles').delete().eq('id', vehicle.id).select('id')
      if (error) throw error
      ensureAffected(data)
      // Remove os arquivos depois do registro (o banco é a referência; arquivos órfãos não quebram nada).
      await removeMedia([...vehicle.vehicle_images.map((i) => i.storage_path), vehicle.model_3d_path]).catch(() => undefined)
    },
    onSuccess: () => invalidate(),
  })
}

export function useAddVehicleImage() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async ({ vehicle, file, view, credit, primary }: { vehicle: VehicleWithMedia; file: File; view: ImageView; credit: string; primary: boolean }) => {
      const prepared = await prepareImage(file)
      const path = `vehicles/${vehicle.id}/${randomName(prepared.extension)}`
      await uploadMedia(path, prepared.blob, prepared.contentType)
      const makePrimary = primary || vehicle.vehicle_images.length === 0
      if (makePrimary && vehicle.vehicle_images.some((i) => i.is_primary)) {
        const { error } = await supabase.from('vehicle_images').update({ is_primary: false }).eq('vehicle_id', vehicle.id)
        if (error) {
          await removeMedia([path]).catch(() => undefined)
          throw error
        }
      }
      const { data, error } = await supabase
        .from('vehicle_images')
        .insert({
          vehicle_id: vehicle.id,
          storage_path: path,
          view,
          source_credit: credit.trim(),
          width: prepared.width,
          height: prepared.height,
          is_primary: makePrimary,
        })
        .select()
        .single()
      if (error) {
        await removeMedia([path]).catch(() => undefined)
        throw error
      }
      return data as VehicleImage
    },
    onSuccess: (img) => invalidate(img.vehicle_id),
  })
}

export function useUpdateVehicleImage() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async ({ image, patch }: { image: VehicleImage; patch: Partial<Pick<VehicleImage, 'glass_masks' | 'view' | 'source_credit'>> }) => {
      const { data, error } = await supabase.from('vehicle_images').update(patch).eq('id', image.id).select()
      if (error) throw error
      return ensureAffected(data)[0] as VehicleImage
    },
    onSuccess: (img) => invalidate(img.vehicle_id),
  })
}

export function useSetPrimaryImage() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async (image: VehicleImage) => {
      const { error: e1 } = await supabase.from('vehicle_images').update({ is_primary: false }).eq('vehicle_id', image.vehicle_id).neq('id', image.id)
      if (e1) throw e1
      const { data, error } = await supabase.from('vehicle_images').update({ is_primary: true }).eq('id', image.id).select()
      if (error) throw error
      return ensureAffected(data)[0] as VehicleImage
    },
    onSuccess: (img) => invalidate(img.vehicle_id),
  })
}

export function useDeleteVehicleImage() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async (image: VehicleImage) => {
      const { data, error } = await supabase.from('vehicle_images').delete().eq('id', image.id).select('id')
      if (error) throw error
      ensureAffected(data)
      await removeMedia([image.storage_path]).catch(() => undefined)
      return image
    },
    onSuccess: (img) => invalidate(img.vehicle_id),
  })
}

export function useUploadModel() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async ({ vehicle, file, credit }: { vehicle: Vehicle; file: File; credit: string }) => {
      if (fileExtension(file.name) !== 'glb') throw new Error('Envie o modelo no formato .glb (glTF binário).')
      if (file.size > 50 * 1024 * 1024) throw new Error('O modelo excede o tamanho máximo de 50 MB.')
      const path = `models/${vehicle.id}/${randomName('glb')}`
      await uploadMedia(path, file, 'model/gltf-binary')
      const { data, error } = await supabase
        .from('vehicles')
        .update({ model_3d_path: path, model_3d_credit: credit.trim(), model_3d_glass_map: {} })
        .eq('id', vehicle.id)
        .select()
      if (error || !data?.length) {
        await removeMedia([path]).catch(() => undefined)
        if (error) throw error
        ensureAffected(data)
      }
      await removeMedia([vehicle.model_3d_path]).catch(() => undefined)
      return data![0] as Vehicle
    },
    onSuccess: (v) => invalidate(v.id),
  })
}

export function useRemoveModel() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async (vehicle: Vehicle) => {
      const { data, error } = await supabase
        .from('vehicles')
        .update({ model_3d_path: null, model_3d_credit: null, model_3d_glass_map: {} })
        .eq('id', vehicle.id)
        .select()
      if (error) throw error
      ensureAffected(data)
      await removeMedia([vehicle.model_3d_path]).catch(() => undefined)
      return vehicle
    },
    onSuccess: (v) => invalidate(v.id),
  })
}

export function useSaveGlassMap() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async ({ vehicleId, map }: { vehicleId: string; map: GlassMap }) => {
      const { data, error } = await supabase.from('vehicles').update({ model_3d_glass_map: map }).eq('id', vehicleId).select('id')
      if (error) throw error
      ensureAffected(data)
      return vehicleId
    },
    onSuccess: (id) => invalidate(id),
  })
}

export function useSaveMasks() {
  const update = useUpdateVehicleImage()
  return {
    ...update,
    mutateAsync: (image: VehicleImage, masks: GlassMasks) => update.mutateAsync({ image, patch: { glass_masks: masks } }),
  }
}

export function useVehicleFilmMutations(vehicleId: string) {
  const qc = useQueryClient()
  const invalidate = () => void qc.invalidateQueries({ queryKey: vehicleKeys.films(vehicleId) })
  const add = useMutation({
    mutationFn: async ({ filmId, priceOverride, notes }: { filmId: string; priceOverride: number | null; notes: string }) => {
      const { error } = await supabase
        .from('vehicle_films')
        .upsert({ vehicle_id: vehicleId, film_id: filmId, price_override: priceOverride, notes }, { onConflict: 'vehicle_id,film_id' })
      if (error) throw error
    },
    onSuccess: invalidate,
  })
  const remove = useMutation({
    mutationFn: async (filmId: string) => {
      const { data, error } = await supabase.from('vehicle_films').delete().eq('vehicle_id', vehicleId).eq('film_id', filmId).select('film_id')
      if (error) throw error
      ensureAffected(data)
    },
    onSuccess: invalidate,
  })
  return { add, remove }
}

export function hasMasks(img: Pick<VehicleImage, 'glass_masks'>) {
  return Object.values(img.glass_masks ?? {}).some((polys) => (polys?.length ?? 0) > 0)
}

export function primaryImage(v: VehicleWithMedia) {
  return v.vehicle_images.find((i) => i.is_primary) ?? v.vehicle_images[0] ?? null
}
