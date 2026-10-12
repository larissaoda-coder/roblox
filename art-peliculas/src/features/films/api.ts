import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ensureAffected } from '@/lib/errors'
import type { Film, FilmFinish, FilmPriceUnit, TechnicalSpec } from '@/types/domain'

export const filmKeys = {
  list: ['films', 'list'] as const,
}

export function useFilms() {
  return useQuery({
    queryKey: filmKeys.list,
    queryFn: async () => {
      const { data, error } = await supabase.from('films').select('*').order('manufacturer').order('name').order('vlt_percent', { ascending: false })
      if (error) throw error
      return data as Film[]
    },
  })
}

export interface FilmInput {
  name: string
  manufacturer: string
  product_line: string
  vlt_percent: number
  finish: FilmFinish
  description: string
  uv_rejection_percent: number | null
  ir_rejection_percent: number | null
  tser_percent: number | null
  warranty_years: number | null
  technical_specs: TechnicalSpec[]
  price: number
  price_unit: FilmPriceUnit
  active: boolean
}

export function useSaveFilm() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, input }: { id?: string; input: FilmInput }) => {
      if (id) {
        const { data, error } = await supabase.from('films').update(input).eq('id', id).select()
        if (error) throw error
        return ensureAffected(data)[0] as Film
      }
      const { data, error } = await supabase.from('films').insert(input).select().single()
      if (error) throw error
      return data as Film
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['films'] })
      void qc.invalidateQueries({ queryKey: ['dashboard'] })
    },
  })
}

export function useDeleteFilm() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (film: Film) => {
      const { data, error } = await supabase.from('films').delete().eq('id', film.id).select('id')
      if (error) throw error
      ensureAffected(data)
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['films'] })
      void qc.invalidateQueries({ queryKey: ['vehicles', 'films'] })
    },
  })
}

export function filmLabel(f: Pick<Film, 'manufacturer' | 'name' | 'product_line' | 'vlt_percent'>) {
  return `${f.manufacturer} ${f.name}${f.product_line ? ` ${f.product_line}` : ''} · ${f.vlt_percent.toLocaleString('pt-BR')}%`
}
