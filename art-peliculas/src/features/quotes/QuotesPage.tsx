import { useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { FileText, Plus } from 'lucide-react'
import { Button, Card, DataTable, EmptyState, Pagination, SearchInput, Tabs, type Column } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { QUOTE_STATUSES, QUOTE_STATUS_LABELS } from '@/lib/constants'
import { useDebounced } from '@/lib/hooks'
import { formatCurrency, formatDate, formatPlate, quoteCode } from '@/lib/format'
import { ErrorState } from '@/features/shared/ErrorState'
import { QuoteStatusBadge } from './StatusBadge'
import { QUOTES_PAGE, useQuotes, type QuoteRow, type QuoteStatusFilter } from './api'

export function QuotesPage() {
  const { can } = useAuth()
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const status = (params.get('status') ?? '') as QuoteStatusFilter
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const debounced = useDebounced(search)
  const { data, isLoading, isFetching, error, refetch } = useQuotes({ status, search: debounced, page })

  const setStatus = (s: QuoteStatusFilter) => {
    const next = new URLSearchParams(params)
    if (s) next.set('status', s)
    else next.delete('status')
    setParams(next, { replace: true })
    setPage(1)
  }

  const columns: Column<QuoteRow>[] = [
    { key: 'number', header: 'Número', cell: (q) => <span className="font-medium text-neutral-950 num">{quoteCode(q.number)}</span> },
    { key: 'customer', header: 'Cliente', cell: (q) => <span className="text-neutral-900">{q.customer?.name ?? '—'}</span> },
    {
      key: 'vehicle',
      header: 'Veículo',
      cell: (q) => (
        <div className="max-w-[220px]">
          <p className="truncate text-neutral-700">{q.vehicle_description || '—'}</p>
          {q.vehicle_plate && <p className="text-xs text-neutral-500 num">{formatPlate(q.vehicle_plate)}</p>}
        </div>
      ),
    },
    { key: 'created', header: 'Data', cell: (q) => <span className="text-neutral-600 num">{formatDate(q.created_at)}</span> },
    { key: 'valid', header: 'Validade', cell: (q) => <span className="text-neutral-600 num">{formatDate(q.valid_until)}</span> },
    { key: 'status', header: 'Status', cell: (q) => <QuoteStatusBadge status={q.status} validUntil={q.valid_until} /> },
    { key: 'total', header: 'Total', align: 'right', cell: (q) => <span className="font-medium text-neutral-950 num">{formatCurrency(q.total)}</span> },
  ]

  return (
    <>
      <PageHeader
        title="Orçamentos"
        description="Acompanhe os orçamentos do rascunho à conclusão do serviço."
        actions={
          can('orcamentos.gerenciar') && (
            <Button icon={<Plus className="h-4 w-4" />} onClick={() => navigate('/app/orcamentos/novo')}>
              Novo orçamento
            </Button>
          )
        }
      />
      <Card>
        <Tabs
          className="px-4 pt-2"
          value={status}
          onChange={setStatus}
          items={[
            { value: '' as QuoteStatusFilter, label: 'Todos' },
            { value: 'pendentes' as QuoteStatusFilter, label: 'Pendentes' },
            ...QUOTE_STATUSES.map((s) => ({ value: s as QuoteStatusFilter, label: QUOTE_STATUS_LABELS[s] })),
          ]}
        />
        <div className="border-b border-neutral-200 p-4">
          <SearchInput
            value={search}
            onChange={(v) => {
              setSearch(v)
              setPage(1)
            }}
            placeholder="Buscar por número (ORC-00012), cliente ou placa"
            aria-label="Buscar orçamentos"
            className="max-w-xl"
          />
        </div>
        {error ? (
          <ErrorState error={error} onRetry={() => void refetch()} />
        ) : (
          <div className={isFetching && !isLoading ? 'opacity-70 transition-opacity' : 'transition-opacity'}>
            <DataTable
              caption="Orçamentos"
              columns={columns}
              rows={data?.rows}
              loading={isLoading}
              rowKey={(q) => q.id}
              onRowClick={(q) => navigate(`/app/orcamentos/${q.id}`)}
              mobileCard={(q) => (
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="font-medium text-neutral-950">
                      {quoteCode(q.number)} · {q.customer?.name}
                    </p>
                    <p className="truncate text-xs text-neutral-500">{q.vehicle_description || 'Veículo não informado'}</p>
                    <div className="mt-1.5">
                      <QuoteStatusBadge status={q.status} validUntil={q.valid_until} />
                    </div>
                  </div>
                  <p className="text-sm font-semibold num">{formatCurrency(q.total)}</p>
                </div>
              )}
              empty={
                <EmptyState
                  icon={FileText}
                  title="Nenhum orçamento encontrado"
                  description={debounced || status ? 'Ajuste a busca ou o filtro de status.' : 'Crie o primeiro orçamento a partir de uma simulação ou do cadastro do cliente.'}
                />
              }
            />
            <Pagination page={page} pageSize={QUOTES_PAGE} total={data?.total ?? 0} onPageChange={setPage} />
          </div>
        )}
      </Card>
    </>
  )
}
