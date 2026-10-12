import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Users } from 'lucide-react'
import { Button, Card, DataTable, EmptyState, Pagination, SearchInput, type Column } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { useDebounced } from '@/lib/hooks'
import { formatDate, formatDocument, formatPhone } from '@/lib/format'
import type { Customer } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { PAGE_SIZE, useCustomers } from './api'
import { CustomerFormModal } from './CustomerFormModal'

export function CustomersPage() {
  const { can } = useAuth()
  const navigate = useNavigate()
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [creating, setCreating] = useState(false)
  const debounced = useDebounced(search)
  const { data, isLoading, isFetching, error, refetch } = useCustomers(debounced, page)

  const columns: Column<Customer>[] = [
    {
      key: 'name',
      header: 'Cliente',
      cell: (c) => (
        <div>
          <p className="font-medium text-neutral-950">{c.name}</p>
          {c.email && <p className="text-xs text-neutral-500">{c.email}</p>}
        </div>
      ),
    },
    { key: 'document', header: 'CPF/CNPJ', cell: (c) => <span className="text-neutral-700 num">{c.document ? formatDocument(c.document) : '—'}</span> },
    { key: 'phone', header: 'Telefone', cell: (c) => <span className="whitespace-nowrap text-neutral-700 num">{c.phone ? formatPhone(c.phone) : '—'}</span> },
    { key: 'city', header: 'Cidade', cell: (c) => <span className="text-neutral-700">{[c.city, c.state].filter(Boolean).join(' / ') || '—'}</span> },
    { key: 'created', header: 'Cadastro', align: 'right', cell: (c) => <span className="text-neutral-500 num">{formatDate(c.created_at)}</span> },
  ]

  return (
    <>
      <PageHeader
        title="Clientes"
        description="Cadastro de clientes com contato, endereço e histórico de orçamentos."
        actions={
          can('clientes.gerenciar') && (
            <Button icon={<Plus className="h-4 w-4" />} onClick={() => setCreating(true)}>
              Novo cliente
            </Button>
          )
        }
      />
      <Card>
        <div className="border-b border-neutral-200 p-4">
          <SearchInput
            value={search}
            onChange={(v) => {
              setSearch(v)
              setPage(1)
            }}
            placeholder="Buscar por nome, CPF/CNPJ, telefone, e-mail ou cidade"
            aria-label="Buscar clientes"
            className="max-w-xl"
          />
        </div>
        {error ? (
          <ErrorState error={error} onRetry={() => void refetch()} />
        ) : (
          <div className={isFetching && !isLoading ? 'opacity-70 transition-opacity' : 'transition-opacity'}>
            <DataTable
              caption="Clientes"
              columns={columns}
              rows={data?.rows}
              loading={isLoading}
              rowKey={(c) => c.id}
              onRowClick={(c) => navigate(`/app/clientes/${c.id}`)}
              mobileCard={(c) => (
                <div>
                  <p className="font-medium text-neutral-950">{c.name}</p>
                  <p className="mt-0.5 text-xs text-neutral-500">
                    {[c.phone ? formatPhone(c.phone) : null, c.city].filter(Boolean).join(' · ') || 'Sem contato informado'}
                  </p>
                </div>
              )}
              empty={
                <EmptyState
                  icon={Users}
                  title={debounced ? 'Nenhum cliente encontrado' : 'Nenhum cliente cadastrado'}
                  description={debounced ? 'Tente outro termo de busca.' : 'Cadastre os clientes para gerar orçamentos e acompanhar os serviços.'}
                />
              }
            />
            <Pagination page={page} pageSize={PAGE_SIZE} total={data?.total ?? 0} onPageChange={setPage} />
          </div>
        )}
      </Card>
      <CustomerFormModal open={creating} onClose={() => setCreating(false)} onSaved={(c) => navigate(`/app/clientes/${c.id}`)} />
    </>
  )
}
