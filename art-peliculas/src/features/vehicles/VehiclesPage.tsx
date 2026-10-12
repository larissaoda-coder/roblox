import { useMemo, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { Box, Car, ImageIcon, Plus } from 'lucide-react'
import { Badge, Button, Card, EmptyState, Select, SearchInput, Skeleton } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { CATEGORIES, CATEGORY_LABELS } from '@/lib/constants'
import { vehicleYears } from '@/lib/format'
import { useSignedUrls } from '@/lib/storage'
import type { VehicleCategory, VehicleWithMedia } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { hasMasks, primaryImage, useVehicles } from './api'
import { VehicleFormModal } from './VehicleFormModal'

function normalize(s: string) {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
}

type MediaFilter = '' | 'com' | 'sem'

export function VehiclesPage() {
  const { can } = useAuth()
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const [creating, setCreating] = useState(false)
  const { data, isLoading, error, refetch } = useVehicles()

  const q = params.get('q') ?? ''
  const category = (params.get('categoria') ?? '') as VehicleCategory | ''
  const brand = params.get('marca') ?? ''
  const media = (params.get('midia') ?? '') as MediaFilter
  const setParam = (key: string, value: string) => {
    const next = new URLSearchParams(params)
    if (value) next.set(key, value)
    else next.delete(key)
    setParams(next, { replace: true })
  }

  const brands = useMemo(() => Array.from(new Set((data ?? []).map((v) => v.brand))).sort((a, b) => a.localeCompare(b, 'pt-BR')), [data])

  const filtered = useMemo(() => {
    const term = normalize(q.trim())
    return (data ?? []).filter((v) => {
      if (category && v.category !== category) return false
      if (brand && v.brand !== brand) return false
      const withMedia = v.vehicle_images.length > 0 || Boolean(v.model_3d_path)
      if (media === 'com' && !withMedia) return false
      if (media === 'sem' && withMedia) return false
      if (term) {
        const hay = normalize(`${v.brand} ${v.model} ${v.generation} ${v.year_start ?? ''} ${v.year_end ?? ''} ${CATEGORY_LABELS[v.category]}`)
        return term.split(/\s+/).every((t) => hay.includes(t))
      }
      return true
    })
  }, [data, q, category, brand, media])

  const imagePaths = filtered.map((v) => primaryImage(v)?.storage_path)
  const urls = useSignedUrls(imagePaths)

  return (
    <>
      <PageHeader
        title="Garagem de veículos"
        description="Biblioteca de modelos com imagens autorizadas, máscaras dos vidros e modelos 3D para o simulador."
        actions={
          can('veiculos.gerenciar') && (
            <Button icon={<Plus className="h-4 w-4" />} onClick={() => setCreating(true)}>
              Novo veículo
            </Button>
          )
        }
      />

      <div className="mb-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-[minmax(0,2fr)_repeat(3,minmax(0,1fr))]">
        <SearchInput value={q} onChange={(v) => setParam('q', v)} placeholder="Buscar por marca, modelo, geração ou ano" aria-label="Buscar veículos" />
        <Select value={brand} onChange={(e) => setParam('marca', e.target.value)} aria-label="Filtrar por marca">
          <option value="">Todas as marcas</option>
          {brands.map((b) => (
            <option key={b} value={b}>
              {b}
            </option>
          ))}
        </Select>
        <Select value={category} onChange={(e) => setParam('categoria', e.target.value)} aria-label="Filtrar por categoria">
          <option value="">Todas as categorias</option>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {CATEGORY_LABELS[c]}
            </option>
          ))}
        </Select>
        <Select value={media} onChange={(e) => setParam('midia', e.target.value)} aria-label="Filtrar por mídia">
          <option value="">Com e sem mídia</option>
          <option value="com">Com imagem ou 3D</option>
          <option value="sem">Sem mídia cadastrada</option>
        </Select>
      </div>

      {error ? (
        <Card>
          <ErrorState error={error} onRetry={() => void refetch()} />
        </Card>
      ) : isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-64 rounded-xl" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <Card>
          <EmptyState
            icon={Car}
            title="Nenhum veículo encontrado"
            description={data?.length ? 'Ajuste a busca ou os filtros.' : 'Cadastre o primeiro veículo da garagem.'}
          />
        </Card>
      ) : (
        <>
          <p className="mb-3 text-xs text-neutral-500">
            {filtered.length} de {data?.length ?? 0} veículos
          </p>
          <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {filtered.map((v) => (
              <li key={v.id}>
                <VehicleCard vehicle={v} imageUrl={urls.data?.[primaryImage(v)?.storage_path ?? '']} onOpen={() => navigate(`/app/garagem/${v.id}`)} />
              </li>
            ))}
          </ul>
        </>
      )}

      <VehicleFormModal open={creating} onClose={() => setCreating(false)} brands={brands} onSaved={(v) => navigate(`/app/garagem/${v.id}`)} />
    </>
  )
}

function VehicleCard({ vehicle: v, imageUrl, onOpen }: { vehicle: VehicleWithMedia; imageUrl?: string; onOpen: () => void }) {
  const img = primaryImage(v)
  const masked = v.vehicle_images.some(hasMasks)
  return (
    <Link
      to={`/app/garagem/${v.id}`}
      onClick={(e) => {
        e.preventDefault()
        onOpen()
      }}
      className="group block overflow-hidden rounded-xl border border-neutral-200 bg-white shadow-soft transition-all duration-200 hover:-translate-y-0.5 hover:border-neutral-300 hover:shadow-lift"
    >
      <div className="relative flex aspect-[4/3] items-center justify-center bg-neutral-100">
        {img && imageUrl ? (
          <img src={imageUrl} alt={`${v.brand} ${v.model}`} loading="lazy" className="h-full w-full object-contain p-2 transition-transform duration-300 group-hover:scale-[1.02]" />
        ) : img ? (
          <Skeleton className="h-full w-full rounded-none" />
        ) : (
          <div className="flex flex-col items-center gap-2 text-neutral-400">
            <Car className="h-8 w-8" strokeWidth={1.25} />
            <span className="text-xs">Sem imagem cadastrada</span>
          </div>
        )}
        {!v.active && (
          <span className="absolute left-3 top-3">
            <Badge tone="subtle">Inativo</Badge>
          </span>
        )}
      </div>
      <div className="p-4">
        <p className="text-xs font-medium uppercase tracking-wide text-neutral-500">{v.brand}</p>
        <p className="mt-0.5 truncate text-[15px] font-semibold text-neutral-950">
          {v.model} {v.generation && <span className="font-normal text-neutral-600">{v.generation}</span>}
        </p>
        <div className="mt-3 flex flex-wrap items-center gap-1.5">
          <Badge tone="muted">{CATEGORY_LABELS[v.category]}</Badge>
          {vehicleYears(v) && <Badge tone="subtle">{vehicleYears(v)}</Badge>}
          {v.model_3d_path && (
            <Badge tone="outline" icon={<Box className="h-3 w-3" />}>
              3D
            </Badge>
          )}
          {masked && (
            <Badge tone="outline" icon={<ImageIcon className="h-3 w-3" />}>
              Máscaras
            </Badge>
          )}
        </div>
      </div>
    </Link>
  )
}
