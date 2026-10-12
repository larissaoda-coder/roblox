import { useMemo, useState } from 'react'
import { Layers, Pencil, Plus, Trash2 } from 'lucide-react'
import { Badge, Button, Card, DataTable, EmptyState, SearchInput, Select, useConfirm, useToast, type Column } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { FINISH_LABELS, PRICE_UNIT_LABELS } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import { formatCurrency, formatPercent } from '@/lib/format'
import { vltToOpacity } from '@/lib/tint'
import type { Film } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { useDeleteFilm, useFilms } from './api'
import { FilmFormModal } from './FilmFormModal'

function normalize(s: string) {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
}

/** Amostra visual do nível de escurecimento (escala de cinza). */
function VltSwatch({ vlt }: { vlt: number }) {
  return (
    <span className="inline-flex items-center gap-2">
      <span className="relative h-5 w-8 overflow-hidden rounded border border-neutral-300 bg-neutral-200" aria-hidden="true">
        <span className="absolute inset-0 bg-neutral-950" style={{ opacity: vltToOpacity(vlt) }} />
      </span>
      <span className="font-medium text-neutral-950 num">{formatPercent(vlt)}</span>
    </span>
  )
}

export function FilmsPage() {
  const { can } = useAuth()
  const canEdit = can('peliculas.gerenciar')
  const { data, isLoading, error, refetch } = useFilms()
  const del = useDeleteFilm()
  const confirm = useConfirm()
  const toast = useToast()
  const [search, setSearch] = useState('')
  const [manufacturer, setManufacturer] = useState('')
  const [status, setStatus] = useState<'ativas' | 'inativas' | ''>('ativas')
  const [editing, setEditing] = useState<Film | null>(null)
  const [creating, setCreating] = useState(false)

  const manufacturers = useMemo(() => Array.from(new Set((data ?? []).map((f) => f.manufacturer))).sort((a, b) => a.localeCompare(b, 'pt-BR')), [data])
  const filtered = useMemo(() => {
    const t = normalize(search.trim())
    return (data ?? []).filter((f) => {
      if (manufacturer && f.manufacturer !== manufacturer) return false
      if (status === 'ativas' && !f.active) return false
      if (status === 'inativas' && f.active) return false
      if (t && !normalize(`${f.name} ${f.manufacturer} ${f.product_line} ${f.vlt_percent}`).includes(t)) return false
      return true
    })
  }, [data, search, manufacturer, status])

  const onDelete = async (film: Film) => {
    const ok = await confirm({
      title: 'Excluir película?',
      description: `${film.manufacturer} ${film.name} será removida do catálogo. Orçamentos existentes mantêm a descrição dos itens. Para apenas ocultar, desative a película.`,
      destructive: true,
    })
    if (!ok) return
    try {
      await del.mutateAsync(film)
      toast.success('Película excluída.')
    } catch (err) {
      toast.error(toMessage(err))
    }
  }

  const columns: Column<Film>[] = [
    {
      key: 'name',
      header: 'Película',
      cell: (f) => (
        <div className="min-w-0">
          <p className="font-medium text-neutral-950">
            {f.name} {!f.active && <Badge tone="dashed" className="ml-1">Inativa</Badge>}
          </p>
          <p className="text-xs text-neutral-500">{[f.manufacturer, f.product_line].filter(Boolean).join(' · ')}</p>
        </div>
      ),
    },
    { key: 'vlt', header: 'Transmissão', cell: (f) => <VltSwatch vlt={f.vlt_percent} /> },
    { key: 'finish', header: 'Aparência', cell: (f) => <span className="text-neutral-600">{FINISH_LABELS[f.finish]}</span> },
    {
      key: 'specs',
      header: 'UV · IR · TSER',
      cell: (f) => (
        <span className="text-neutral-600 num">
          {[f.uv_rejection_percent, f.ir_rejection_percent, f.tser_percent].map((v) => (v === null ? '—' : formatPercent(v))).join(' · ')}
        </span>
      ),
    },
    {
      key: 'price',
      header: 'Preço',
      align: 'right',
      cell: (f) => (
        <span className="whitespace-nowrap">
          <span className="font-medium text-neutral-950 num">{formatCurrency(f.price)}</span>{' '}
          <span className="text-xs text-neutral-500">{PRICE_UNIT_LABELS[f.price_unit]}</span>
        </span>
      ),
    },
    ...(canEdit
      ? [
          {
            key: 'actions',
            header: <span className="sr-only">Ações</span>,
            align: 'right' as const,
            cell: (f: Film) => (
              <div className="flex justify-end gap-1" onClick={(e) => e.stopPropagation()}>
                <Button size="icon-sm" variant="ghost" aria-label={`Editar ${f.name}`} onClick={() => setEditing(f)}>
                  <Pencil className="h-4 w-4" />
                </Button>
                <Button size="icon-sm" variant="ghost" aria-label={`Excluir ${f.name}`} onClick={() => onDelete(f)}>
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            ),
          },
        ]
      : []),
  ]

  return (
    <>
      <PageHeader
        title="Catálogo de películas"
        description="Produtos com transmissão luminosa, características técnicas e preços informados pelo administrador."
        actions={
          canEdit && (
            <Button icon={<Plus className="h-4 w-4" />} onClick={() => setCreating(true)}>
              Nova película
            </Button>
          )
        }
      />
      <Card>
        <div className="grid gap-3 border-b border-neutral-200 p-4 sm:grid-cols-[minmax(0,2fr)_repeat(2,minmax(0,1fr))]">
          <SearchInput value={search} onChange={setSearch} placeholder="Buscar por nome, fabricante ou VLT" aria-label="Buscar películas" />
          <Select value={manufacturer} onChange={(e) => setManufacturer(e.target.value)} aria-label="Filtrar por fabricante">
            <option value="">Todos os fabricantes</option>
            {manufacturers.map((m) => (
              <option key={m} value={m}>
                {m}
              </option>
            ))}
          </Select>
          <Select value={status} onChange={(e) => setStatus(e.target.value as typeof status)} aria-label="Filtrar por situação">
            <option value="ativas">Somente ativas</option>
            <option value="inativas">Somente inativas</option>
            <option value="">Todas</option>
          </Select>
        </div>
        {error ? (
          <ErrorState error={error} onRetry={() => void refetch()} />
        ) : (
          <DataTable
            caption="Películas cadastradas"
            columns={columns}
            rows={filtered}
            loading={isLoading}
            rowKey={(f) => f.id}
            onRowClick={canEdit ? (f) => setEditing(f) : undefined}
            mobileCard={(f) => (
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="truncate font-medium text-neutral-950">{f.name}</p>
                  <p className="truncate text-xs text-neutral-500">{[f.manufacturer, f.product_line].filter(Boolean).join(' · ')}</p>
                  <p className="mt-1 text-xs text-neutral-700">
                    {formatCurrency(f.price)} {PRICE_UNIT_LABELS[f.price_unit]}
                  </p>
                </div>
                <VltSwatch vlt={f.vlt_percent} />
              </div>
            )}
            empty={
              <EmptyState
                icon={Layers}
                title={data?.length ? 'Nenhuma película encontrada' : 'Catálogo vazio'}
                description={data?.length ? 'Ajuste a busca ou os filtros.' : 'Cadastre as películas que a loja trabalha, com os dados da ficha técnica do fabricante.'}
                action={
                  canEdit &&
                  !data?.length && (
                    <Button icon={<Plus className="h-4 w-4" />} onClick={() => setCreating(true)}>
                      Cadastrar película
                    </Button>
                  )
                }
              />
            }
          />
        )}
      </Card>
      <FilmFormModal open={creating || editing !== null} film={editing} manufacturers={manufacturers} onClose={() => (setCreating(false), setEditing(null))} />
    </>
  )
}
