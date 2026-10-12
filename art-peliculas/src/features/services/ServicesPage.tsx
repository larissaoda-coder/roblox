import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Link } from 'react-router-dom'
import { ClipboardList, Pencil, Plus, Trash2, Wrench } from 'lucide-react'
import { Badge, Button, Card, DataTable, EmptyState, Pagination, SearchInput, Select, Tabs, useConfirm, useToast, type Column } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { SERVICE_STATUSES, SERVICE_STATUS_LABELS } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import { useDebounced } from '@/lib/hooks'
import { formatCurrency, formatDateTime, formatPlate, quoteCode, serviceOrderCode } from '@/lib/format'
import type { ServiceOrderStatus, ServiceType } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { ServiceStatusBadge } from '@/features/quotes/StatusBadge'
import { ORDERS_PAGE, useDeleteServiceOrder, useDeleteServiceType, useSaveServiceOrder, useServiceOrders, useServiceTypes, type ServiceOrderRow } from './api'
import { ServiceOrderFormModal } from './ServiceOrderFormModal'
import { ServiceTypeFormModal } from './ServiceTypeFormModal'

type TabValue = 'ordens' | 'tipos'

export function ServicesPage() {
  const [params, setParams] = useSearchParams()
  const tab = (params.get('aba') ?? 'ordens') as TabValue
  return (
    <>
      <PageHeader title="Serviços" description="Ordens de serviço da equipe e tipos de serviço oferecidos pela loja." />
      <Tabs
        className="mb-6"
        value={tab}
        onChange={(v) => setParams(v === 'ordens' ? {} : { aba: v }, { replace: true })}
        items={[
          { value: 'ordens', label: 'Ordens de serviço' },
          { value: 'tipos', label: 'Tipos de serviço' },
        ]}
      />
      {tab === 'ordens' ? <OrdersTab /> : <TypesTab />}
    </>
  )
}

function OrdersTab() {
  const { can } = useAuth()
  const canEdit = can('servicos.gerenciar')
  const [status, setStatus] = useState<ServiceOrderStatus | 'abertas' | ''>('abertas')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [editing, setEditing] = useState<ServiceOrderRow | null>(null)
  const [creating, setCreating] = useState(false)
  const debounced = useDebounced(search)
  const { data, isLoading, error, refetch } = useServiceOrders({ status, search: debounced, page })
  const save = useSaveServiceOrder()
  const del = useDeleteServiceOrder()
  const toast = useToast()
  const confirm = useConfirm()

  const changeStatus = async (o: ServiceOrderRow, next: ServiceOrderStatus) => {
    try {
      await save.mutateAsync({ id: o.id, input: { status: next } })
      toast.success(`${serviceOrderCode(o.number)}: ${SERVICE_STATUS_LABELS[next].toLowerCase()}.`)
    } catch (err) {
      toast.error(toMessage(err))
    }
  }

  const columns: Column<ServiceOrderRow>[] = [
    { key: 'number', header: 'OS', cell: (o) => <span className="font-medium text-neutral-950 num">{serviceOrderCode(o.number)}</span> },
    {
      key: 'when',
      header: 'Agendamento',
      cell: (o) => <span className="whitespace-nowrap text-neutral-700 num">{o.scheduled_at ? formatDateTime(o.scheduled_at) : 'Sem data'}</span>,
    },
    {
      key: 'customer',
      header: 'Cliente / veículo',
      cell: (o) => (
        <div className="max-w-[260px]">
          <p className="truncate text-neutral-950">{o.customer?.name}</p>
          <p className="truncate text-xs text-neutral-500">{[o.vehicle_description, o.vehicle_plate ? formatPlate(o.vehicle_plate) : null].filter(Boolean).join(' · ') || '—'}</p>
        </div>
      ),
    },
    {
      key: 'desc',
      header: 'Serviço',
      cell: (o) => (
        <div className="max-w-[260px]">
          <p className="truncate text-neutral-800">{o.description}</p>
          <p className="text-xs text-neutral-500">
            {[o.service_type?.name, o.quote ? quoteCode(o.quote.number) : null].filter(Boolean).join(' · ')}
          </p>
        </div>
      ),
    },
    { key: 'assignee', header: 'Responsável', cell: (o) => <span className="text-neutral-700">{o.assignee?.full_name ?? '—'}</span> },
    {
      key: 'status',
      header: 'Situação',
      cell: (o) =>
        canEdit ? (
          <Select
            aria-label={`Situação de ${serviceOrderCode(o.number)}`}
            className="h-8 w-36 text-xs"
            value={o.status}
            onClick={(e) => e.stopPropagation()}
            onChange={(e) => changeStatus(o, e.target.value as ServiceOrderStatus)}
          >
            {SERVICE_STATUSES.map((s) => (
              <option key={s} value={s}>
                {SERVICE_STATUS_LABELS[s]}
              </option>
            ))}
          </Select>
        ) : (
          <ServiceStatusBadge status={o.status} />
        ),
    },
    { key: 'price', header: 'Valor', align: 'right', cell: (o) => <span className="num">{o.price != null ? formatCurrency(o.price) : '—'}</span> },
    ...(canEdit
      ? [
          {
            key: 'actions',
            header: <span className="sr-only">Ações</span>,
            align: 'right' as const,
            cell: (o: ServiceOrderRow) => (
              <div className="flex justify-end gap-1" onClick={(e) => e.stopPropagation()}>
                <Button size="icon-sm" variant="ghost" aria-label={`Editar ${serviceOrderCode(o.number)}`} onClick={() => setEditing(o)}>
                  <Pencil className="h-4 w-4" />
                </Button>
                <Button
                  size="icon-sm"
                  variant="ghost"
                  aria-label={`Excluir ${serviceOrderCode(o.number)}`}
                  onClick={async () => {
                    if (!(await confirm({ title: `Excluir ${serviceOrderCode(o.number)}?`, destructive: true }))) return
                    del.mutateAsync(o.id).then(() => toast.success('Ordem de serviço excluída.'), (e) => toast.error(toMessage(e)))
                  }}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            ),
          },
        ]
      : []),
  ]

  return (
    <Card>
      <div className="flex flex-col gap-3 border-b border-neutral-200 p-4 sm:flex-row sm:items-center">
        <SearchInput
          className="flex-1"
          value={search}
          onChange={(v) => {
            setSearch(v)
            setPage(1)
          }}
          placeholder="Buscar por número (OS-00012), descrição, veículo ou placa"
          aria-label="Buscar ordens de serviço"
        />
        <Select
          className="sm:w-52"
          value={status}
          onChange={(e) => {
            setStatus(e.target.value as typeof status)
            setPage(1)
          }}
          aria-label="Filtrar por situação"
        >
          <option value="abertas">Em aberto</option>
          <option value="">Todas</option>
          {SERVICE_STATUSES.map((s) => (
            <option key={s} value={s}>
              {SERVICE_STATUS_LABELS[s]}
            </option>
          ))}
        </Select>
        {canEdit && (
          <Button icon={<Plus className="h-4 w-4" />} onClick={() => setCreating(true)}>
            Nova ordem
          </Button>
        )}
      </div>
      {error ? (
        <ErrorState error={error} onRetry={() => void refetch()} />
      ) : (
        <>
          <DataTable
            caption="Ordens de serviço"
            columns={columns}
            rows={data?.rows}
            loading={isLoading}
            rowKey={(o) => o.id}
            onRowClick={canEdit ? (o) => setEditing(o) : undefined}
            mobileCard={(o) => (
              <div className="space-y-1">
                <div className="flex items-center justify-between gap-2">
                  <p className="font-medium text-neutral-950">
                    {serviceOrderCode(o.number)} · {o.customer?.name}
                  </p>
                  <ServiceStatusBadge status={o.status} />
                </div>
                <p className="text-xs text-neutral-500">{o.scheduled_at ? formatDateTime(o.scheduled_at) : 'Sem data'}</p>
                <p className="truncate text-sm text-neutral-700">{o.description}</p>
              </div>
            )}
            empty={
              <EmptyState
                icon={ClipboardList}
                title="Nenhuma ordem de serviço"
                description={
                  <>
                    Registre serviços manualmente ou gere a partir de um{' '}
                    <Link to="/app/orcamentos?status=aprovado" className="font-medium text-neutral-900 underline underline-offset-4">
                      orçamento aprovado
                    </Link>
                    .
                  </>
                }
              />
            }
          />
          <Pagination page={page} pageSize={ORDERS_PAGE} total={data?.total ?? 0} onPageChange={setPage} />
        </>
      )}
      <ServiceOrderFormModal open={creating || editing !== null} order={editing} onClose={() => (setCreating(false), setEditing(null))} />
    </Card>
  )
}

function TypesTab() {
  const { can } = useAuth()
  const canEdit = can('servicos.gerenciar')
  const { data, isLoading, error, refetch } = useServiceTypes()
  const del = useDeleteServiceType()
  const toast = useToast()
  const confirm = useConfirm()
  const [editing, setEditing] = useState<ServiceType | null>(null)
  const [creating, setCreating] = useState(false)

  const columns: Column<ServiceType>[] = [
    {
      key: 'name',
      header: 'Serviço',
      cell: (t) => (
        <div>
          <p className="font-medium text-neutral-950">
            {t.name} {!t.active && <Badge tone="dashed" className="ml-1">Inativo</Badge>}
          </p>
          {t.description && <p className="max-w-md truncate text-xs text-neutral-500">{t.description}</p>}
        </div>
      ),
    },
    { key: 'time', header: 'Tempo estimado', cell: (t) => <span className="text-neutral-600">{t.estimated_minutes ? `${t.estimated_minutes} min` : '—'}</span> },
    { key: 'price', header: 'Preço base', align: 'right', cell: (t) => <span className="font-medium num">{formatCurrency(t.base_price)}</span> },
    ...(canEdit
      ? [
          {
            key: 'actions',
            header: <span className="sr-only">Ações</span>,
            align: 'right' as const,
            cell: (t: ServiceType) => (
              <div className="flex justify-end gap-1" onClick={(e) => e.stopPropagation()}>
                <Button size="icon-sm" variant="ghost" aria-label={`Editar ${t.name}`} onClick={() => setEditing(t)}>
                  <Pencil className="h-4 w-4" />
                </Button>
                <Button
                  size="icon-sm"
                  variant="ghost"
                  aria-label={`Excluir ${t.name}`}
                  onClick={async () => {
                    if (!(await confirm({ title: 'Excluir tipo de serviço?', description: 'Itens de orçamentos existentes mantêm a descrição.', destructive: true }))) return
                    del.mutateAsync(t.id).then(() => toast.success('Tipo de serviço excluído.'), (e) => toast.error(toMessage(e)))
                  }}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            ),
          },
        ]
      : []),
  ]

  return (
    <Card>
      {canEdit && (
        <div className="flex justify-end border-b border-neutral-200 p-4">
          <Button icon={<Plus className="h-4 w-4" />} onClick={() => setCreating(true)}>
            Novo tipo de serviço
          </Button>
        </div>
      )}
      {error ? (
        <ErrorState error={error} onRetry={() => void refetch()} />
      ) : (
        <DataTable
          caption="Tipos de serviço"
          columns={columns}
          rows={data}
          loading={isLoading}
          rowKey={(t) => t.id}
          onRowClick={canEdit ? (t) => setEditing(t) : undefined}
          empty={<EmptyState icon={Wrench} title="Nenhum tipo de serviço" description="Cadastre os serviços que a loja oferece (instalação, remoção, polimento etc.) com preço base." />}
        />
      )}
      <ServiceTypeFormModal open={creating || editing !== null} type={editing} onClose={() => (setCreating(false), setEditing(null))} />
    </Card>
  )
}
