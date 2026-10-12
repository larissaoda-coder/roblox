import { useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Car, ImageIcon, ImagePlus, Layers, Pencil, Plus, Star, SunDim, Trash2, X } from 'lucide-react'
import {
  Badge,
  Button,
  Card,
  CardBody,
  CardHeader,
  Combobox,
  EmptyState,
  Field,
  Input,
  Modal,
  PageLoader,
  Skeleton,
  useConfirm,
  useToast,
} from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { CATEGORY_LABELS, PRICE_UNIT_LABELS, VIEW_LABELS, ZONE_SHORT } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import { formatCurrency, formatDateTime, parseDecimal, vehicleName, vehicleYears } from '@/lib/format'
import { toSvgPoints, zonesWithMasks } from '@/lib/geometry'
import { useSignedUrls } from '@/lib/storage'
import type { VehicleImage, VehicleWithMedia } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { filmLabel, useFilms } from '@/features/films/api'
import {
  useDeleteVehicle,
  useDeleteVehicleImage,
  useSaveMasks,
  useSetPrimaryImage,
  useVehicle,
  useVehicleFilmMutations,
  useVehicleFilms,
  useVehicles,
} from './api'
import { VehicleFormModal } from './VehicleFormModal'
import { ImageUploadModal } from './ImageUploadModal'
import { MaskEditor } from './MaskEditor'
import { Model3DPanel } from './Model3DPanel'

export function VehicleDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { can } = useAuth()
  const canEdit = can('veiculos.gerenciar')
  const { data: vehicle, isLoading, error, refetch } = useVehicle(id)
  const { data: all } = useVehicles()
  const [editing, setEditing] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [maskImage, setMaskImage] = useState<VehicleImage | null>(null)
  const del = useDeleteVehicle()
  const confirm = useConfirm()
  const toast = useToast()

  const brands = useMemo(() => Array.from(new Set((all ?? []).map((v) => v.brand))).sort(), [all])
  const urls = useSignedUrls(vehicle?.vehicle_images.map((i) => i.storage_path) ?? [])

  if (isLoading) return <PageLoader />
  if (error) return <ErrorState error={error} onRetry={() => void refetch()} />
  if (!vehicle) {
    return <EmptyState icon={Car} title="Veículo não encontrado" description="Ele pode ter sido removido da garagem." className="py-24" />
  }

  const onDelete = async () => {
    const ok = await confirm({
      title: 'Excluir veículo?',
      description: `${vehicleName(vehicle)} será removido da garagem com suas imagens, máscaras, modelo 3D e simulações. Orçamentos existentes mantêm a descrição do veículo.`,
      destructive: true,
    })
    if (!ok) return
    try {
      await del.mutateAsync(vehicle)
      toast.success('Veículo excluído.')
      navigate('/app/garagem')
    } catch (err) {
      toast.error(toMessage(err))
    }
  }

  return (
    <>
      <PageHeader
        backTo="/app/garagem"
        backLabel="Garagem"
        eyebrow={vehicle.brand}
        title={
          <>
            {vehicle.model} <span className="font-normal text-neutral-500">{vehicle.generation}</span>
          </>
        }
        description={
          <span className="inline-flex flex-wrap items-center gap-1.5">
            <Badge tone="muted">{CATEGORY_LABELS[vehicle.category]}</Badge>
            {vehicleYears(vehicle) && <Badge tone="subtle">{vehicleYears(vehicle)}</Badge>}
            {vehicle.doors && <Badge tone="subtle">{vehicle.doors} portas</Badge>}
            {!vehicle.active && <Badge tone="dashed">Inativo</Badge>}
          </span>
        }
        actions={
          <>
            <Button icon={<SunDim className="h-4 w-4" />} onClick={() => navigate(`/app/simulador?veiculo=${vehicle.id}`)}>
              Simular películas
            </Button>
            {canEdit && (
              <>
                <Button variant="secondary" icon={<Pencil className="h-4 w-4" />} onClick={() => setEditing(true)}>
                  Editar
                </Button>
                <Button variant="ghost" size="icon" aria-label="Excluir veículo" onClick={onDelete}>
                  <Trash2 className="h-4 w-4" />
                </Button>
              </>
            )}
          </>
        }
      />

      {vehicle.notes && <p className="-mt-3 mb-6 max-w-3xl text-sm text-neutral-600">{vehicle.notes}</p>}

      <div className="space-y-6">
        <Card>
          <CardHeader
            title="Imagens autorizadas"
            description="Cada imagem precisa de máscaras dos vidros para ser usada no simulador."
            actions={
              canEdit && (
                <Button size="sm" icon={<ImagePlus className="h-4 w-4" />} onClick={() => setUploading(true)}>
                  Adicionar imagem
                </Button>
              )
            }
          />
          {vehicle.vehicle_images.length === 0 ? (
            <EmptyState
              icon={ImageIcon}
              title="Nenhuma imagem cadastrada"
              description="Envie fotos deste modelo com origem e autorização informadas. Enquanto isso, o simulador usa um modelo genérico de referência, identificado como tal."
            />
          ) : (
            <ul className="grid gap-4 p-5 sm:grid-cols-2 xl:grid-cols-3">
              {vehicle.vehicle_images.map((img) => (
                <ImageTile key={img.id} image={img} url={urls.data?.[img.storage_path]} canEdit={canEdit} onEditMasks={() => setMaskImage(img)} />
              ))}
            </ul>
          )}
        </Card>

        <Model3DPanel vehicle={vehicle} canEdit={canEdit} />

        <VehicleFilmsPanel vehicle={vehicle} canEdit={can('veiculos.gerenciar') || can('peliculas.gerenciar')} />

        <p className="text-xs text-neutral-400">Atualizado em {formatDateTime(vehicle.updated_at)}</p>
      </div>

      <VehicleFormModal open={editing} onClose={() => setEditing(false)} vehicle={vehicle} brands={brands} />
      <ImageUploadModal open={uploading} onClose={() => setUploading(false)} vehicle={vehicle} onUploaded={(img) => setMaskImage(img)} />
      <MaskModal image={maskImage} url={maskImage ? urls.data?.[maskImage.storage_path] : undefined} onClose={() => setMaskImage(null)} />
    </>
  )
}

function ImageTile({ image, url, canEdit, onEditMasks }: { image: VehicleImage; url?: string; canEdit: boolean; onEditMasks: () => void }) {
  const setPrimary = useSetPrimaryImage()
  const remove = useDeleteVehicleImage()
  const confirm = useConfirm()
  const toast = useToast()
  const zones = zonesWithMasks(image.glass_masks)
  const w = image.width ?? 1600
  const h = image.height ?? 1000

  return (
    <li className="overflow-hidden rounded-lg border border-neutral-200">
      <div className="relative bg-neutral-100" style={{ aspectRatio: `${w} / ${h}` }}>
        {url ? (
          <svg viewBox={`0 0 ${w} ${h}`} className="h-full w-full">
            <image href={url} width={w} height={h} />
            {zones.flatMap((z) =>
              (image.glass_masks[z] ?? []).map((poly, i) => (
                <polygon key={`${z}${i}`} points={toSvgPoints(poly, w, h)} fill="#0a0a0a" fillOpacity={0.12} stroke="#0a0a0a" strokeWidth={Math.max(1.5, w / 600)} strokeDasharray={`${w / 150} ${w / 220}`} />
              )),
            )}
          </svg>
        ) : (
          <Skeleton className="h-full w-full rounded-none" />
        )}
        {image.is_primary && (
          <span className="absolute left-2 top-2">
            <Badge tone="solid" icon={<Star className="h-3 w-3" />}>
              Principal
            </Badge>
          </span>
        )}
      </div>
      <div className="space-y-2 p-3">
        <div className="flex items-center justify-between gap-2">
          <p className="text-sm font-medium text-neutral-900">{VIEW_LABELS[image.view]}</p>
          {zones.length ? <Badge tone="outline">{zones.length} zona(s) com máscara</Badge> : <Badge tone="dashed">Sem máscaras</Badge>}
        </div>
        {zones.length > 0 && <p className="text-xs text-neutral-500">{zones.map((z) => ZONE_SHORT[z]).join(' · ')}</p>}
        <p className="line-clamp-2 text-xs text-neutral-500" title={image.source_credit}>
          Origem: {image.source_credit}
        </p>
        {canEdit && (
          <div className="flex flex-wrap gap-1.5 pt-1">
            <Button size="sm" variant="secondary" onClick={onEditMasks}>
              {zones.length ? 'Editar máscaras' : 'Desenhar máscaras'}
            </Button>
            {!image.is_primary && (
              <Button
                size="sm"
                variant="ghost"
                loading={setPrimary.isPending}
                onClick={() => setPrimary.mutateAsync(image).then(() => toast.success('Imagem principal atualizada.'), (e) => toast.error(toMessage(e)))}
              >
                Tornar principal
              </Button>
            )}
            <Button
              size="icon-sm"
              variant="ghost"
              aria-label="Excluir imagem"
              onClick={async () => {
                const ok = await confirm({ title: 'Excluir imagem?', description: 'A imagem e suas máscaras serão removidas.', destructive: true })
                if (!ok) return
                remove.mutateAsync(image).then(() => toast.success('Imagem excluída.'), (e) => toast.error(toMessage(e)))
              }}
            >
              <Trash2 className="h-3.5 w-3.5" />
            </Button>
          </div>
        )}
      </div>
    </li>
  )
}

function MaskModal({ image, url, onClose }: { image: VehicleImage | null; url?: string; onClose: () => void }) {
  const save = useSaveMasks()
  const toast = useToast()
  const [dims, setDims] = useState<{ w: number; h: number } | null>(null)
  const w = image?.width ?? dims?.w
  const h = image?.height ?? dims?.h

  return (
    <Modal open={image !== null} onClose={onClose} title="Máscaras dos vidros" description="Marque somente as áreas envidraçadas de cada zona." size="full" dismissible={false}>
      {image && url && w && h ? (
        <MaskEditor
          imageUrl={url}
          width={w}
          height={h}
          initial={image.glass_masks}
          saving={save.isPending}
          onCancel={onClose}
          onSave={async (masks) => {
            try {
              await save.mutateAsync(image, masks)
              toast.success('Máscaras salvas.')
              onClose()
            } catch (err) {
              toast.error(toMessage(err))
            }
          }}
        />
      ) : image && url ? (
        <img src={url} alt="" className="hidden" onLoad={(e) => setDims({ w: e.currentTarget.naturalWidth, h: e.currentTarget.naturalHeight })} />
      ) : (
        <PageLoader label="Carregando imagem…" />
      )}
    </Modal>
  )
}

function VehicleFilmsPanel({ vehicle, canEdit }: { vehicle: VehicleWithMedia; canEdit: boolean }) {
  const { data: rows, isLoading } = useVehicleFilms(vehicle.id)
  const { data: films } = useFilms()
  const { add, remove } = useVehicleFilmMutations(vehicle.id)
  const toast = useToast()
  const [adding, setAdding] = useState(false)
  const [filmId, setFilmId] = useState<string | null>(null)
  const [price, setPrice] = useState('')
  const [notes, setNotes] = useState('')

  const options = (films ?? [])
    .filter((f) => f.active && !rows?.some((r) => r.film_id === f.id))
    .map((f) => ({ value: f.id, label: filmLabel(f), description: `${formatCurrency(f.price)} ${PRICE_UNIT_LABELS[f.price_unit]}` }))

  const submit = async () => {
    if (!filmId) return
    const value = price.trim() ? parseDecimal(price) : null
    if (value !== null && (!Number.isFinite(value) || value < 0)) return toast.error('Preço inválido.')
    try {
      await add.mutateAsync({ filmId, priceOverride: value, notes: notes.trim() })
      toast.success('Película associada ao veículo.')
      setAdding(false)
      setFilmId(null)
      setPrice('')
      setNotes('')
    } catch (err) {
      toast.error(toMessage(err))
    }
  }

  return (
    <Card>
      <CardHeader
        title="Películas indicadas"
        description="Sugeridas no simulador e nos orçamentos deste veículo, com preço específico opcional."
        actions={
          canEdit && (
            <Button size="sm" variant="secondary" icon={<Plus className="h-4 w-4" />} onClick={() => setAdding(true)}>
              Associar película
            </Button>
          )
        }
      />
      {isLoading ? (
        <CardBody>
          <Skeleton className="h-12 w-full" />
        </CardBody>
      ) : rows && rows.length > 0 ? (
        <ul className="divide-y divide-neutral-100">
          {rows.map((r) => (
            <li key={r.film_id} className="flex items-center gap-4 px-5 py-3">
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-neutral-900">{filmLabel(r.film)}</p>
                <p className="truncate text-xs text-neutral-500">
                  {r.price_override !== null ? `Preço para este veículo: ${formatCurrency(r.price_override)}` : `Preço do catálogo: ${formatCurrency(r.film.price)} ${PRICE_UNIT_LABELS[r.film.price_unit]}`}
                  {r.notes ? ` · ${r.notes}` : ''}
                </p>
              </div>
              {canEdit && (
                <Button
                  size="icon-sm"
                  variant="ghost"
                  aria-label="Remover associação"
                  onClick={() => remove.mutateAsync(r.film_id).then(() => toast.success('Associação removida.'), (e) => toast.error(toMessage(e)))}
                >
                  <X className="h-4 w-4" />
                </Button>
              )}
            </li>
          ))}
        </ul>
      ) : (
        <EmptyState icon={Layers} title="Nenhuma película associada" description="Associe películas do catálogo para agilizar simulações e orçamentos." />
      )}

      <Modal
        open={adding}
        onClose={() => setAdding(false)}
        title="Associar película"
        footer={
          <>
            <Button variant="secondary" onClick={() => setAdding(false)}>
              Cancelar
            </Button>
            <Button onClick={submit} loading={add.isPending} disabled={!filmId}>
              Associar
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          <Field label="Película" required>
            <Combobox value={filmId} onChange={(v) => setFilmId(v)} options={options} placeholder="Buscar no catálogo…" emptyText="Nenhuma película disponível. Cadastre no catálogo." />
          </Field>
          <Field label="Preço para este veículo (opcional)" hint="Deixe em branco para usar o preço do catálogo.">
            <Input inputMode="decimal" placeholder="0,00" value={price} onChange={(e) => setPrice(e.target.value)} />
          </Field>
          <Field label="Observação (opcional)">
            <Input value={notes} onChange={(e) => setNotes(e.target.value)} maxLength={500} />
          </Field>
        </div>
      </Modal>
    </Card>
  )
}
