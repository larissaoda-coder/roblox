import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { FileText, Mail, MapPin, Pencil, Phone, Plus, SunDim, Trash2, UserRound, Wrench } from 'lucide-react'
import { Button, Card, CardBody, CardHeader, EmptyState, PageLoader, Skeleton, useConfirm, useToast } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { supabase } from '@/lib/supabase'
import { toMessage } from '@/lib/errors'
import { MODE_LABELS, ZONES, ZONE_SHORT } from '@/lib/constants'
import { formatCurrency, formatDate, formatDateTime, formatDocument, formatPhone, formatZip, quoteCode, serviceOrderCode, vehicleName } from '@/lib/format'
import type { Quote, ServiceOrder, Simulation } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { QuoteStatusBadge, ServiceStatusBadge } from '@/features/quotes/StatusBadge'
import { useCustomer, useDeleteCustomer } from './api'
import { CustomerFormModal } from './CustomerFormModal'

type SimRow = Simulation & { vehicle: { brand: string; model: string; generation: string } | null }

function useCustomerActivity(id: string | undefined) {
  return useQuery({
    queryKey: ['customers', 'activity', id],
    enabled: Boolean(id),
    queryFn: async () => {
      const [quotes, orders, sims] = await Promise.all([
        supabase.from('quotes').select('*').eq('customer_id', id!).order('created_at', { ascending: false }),
        supabase.from('service_orders').select('*').eq('customer_id', id!).order('created_at', { ascending: false }),
        supabase.from('simulations').select('*, vehicle:vehicles(brand, model, generation)').eq('customer_id', id!).order('created_at', { ascending: false }).limit(20),
      ])
      for (const r of [quotes, orders, sims]) if (r.error) throw r.error
      return { quotes: quotes.data as Quote[], orders: orders.data as ServiceOrder[], simulations: sims.data as unknown as SimRow[] }
    },
  })
}

export function CustomerDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { can } = useAuth()
  const { data: customer, isLoading, error, refetch } = useCustomer(id)
  const activity = useCustomerActivity(id)
  const del = useDeleteCustomer()
  const confirm = useConfirm()
  const toast = useToast()
  const [editing, setEditing] = useState(false)

  if (isLoading) return <PageLoader />
  if (error) return <ErrorState error={error} onRetry={() => void refetch()} />
  if (!customer) return <EmptyState icon={UserRound} title="Cliente não encontrado" className="py-24" />

  const address = [
    [customer.street, customer.address_number].filter(Boolean).join(', '),
    customer.complement,
    customer.district,
    [customer.city, customer.state].filter(Boolean).join(' / '),
    customer.zip_code ? `CEP ${formatZip(customer.zip_code)}` : '',
  ]
    .filter(Boolean)
    .join(' · ')

  const onDelete = async () => {
    const ok = await confirm({
      title: 'Excluir cliente?',
      description: `${customer.name} será removido. Clientes com orçamentos ou ordens de serviço não podem ser excluídos.`,
      destructive: true,
    })
    if (!ok) return
    try {
      await del.mutateAsync(customer.id)
      toast.success('Cliente excluído.')
      navigate('/app/clientes')
    } catch (err) {
      toast.error(toMessage(err))
    }
  }

  return (
    <>
      <PageHeader
        backTo="/app/clientes"
        backLabel="Clientes"
        title={customer.name}
        description={`Cliente desde ${formatDate(customer.created_at)}`}
        actions={
          <>
            {can('orcamentos.gerenciar') && (
              <Button icon={<Plus className="h-4 w-4" />} onClick={() => navigate(`/app/orcamentos/novo?cliente=${customer.id}`)}>
                Novo orçamento
              </Button>
            )}
            <Button variant="secondary" icon={<SunDim className="h-4 w-4" />} onClick={() => navigate(`/app/simulador?cliente=${customer.id}`)}>
              Simular
            </Button>
            {can('clientes.gerenciar') && (
              <Button variant="secondary" icon={<Pencil className="h-4 w-4" />} onClick={() => setEditing(true)}>
                Editar
              </Button>
            )}
            {can('clientes.excluir') && (
              <Button variant="ghost" size="icon" aria-label="Excluir cliente" onClick={onDelete}>
                <Trash2 className="h-4 w-4" />
              </Button>
            )}
          </>
        }
      />

      <div className="grid gap-6 lg:grid-cols-[320px_minmax(0,1fr)]">
        <Card className="h-fit">
          <CardHeader title="Dados do cliente" />
          <CardBody className="space-y-4 text-sm">
            <Info icon={UserRound} label="CPF/CNPJ" value={customer.document ? formatDocument(customer.document) : null} />
            <Info icon={Phone} label="Telefone" value={customer.phone ? formatPhone(customer.phone) : null} />
            <Info icon={Mail} label="E-mail" value={customer.email} />
            <Info icon={MapPin} label="Endereço" value={address || null} />
            {customer.notes && (
              <div>
                <p className="eyebrow mb-1">Observações</p>
                <p className="whitespace-pre-line text-neutral-700">{customer.notes}</p>
              </div>
            )}
          </CardBody>
        </Card>

        <div className="space-y-6">
          <Card>
            <CardHeader title="Orçamentos" description={activity.data ? `${activity.data.quotes.length} no total` : undefined} />
            {activity.isLoading ? (
              <CardBody>
                <Skeleton className="h-12" />
              </CardBody>
            ) : activity.error ? (
              <ErrorState error={activity.error} onRetry={() => void activity.refetch()} />
            ) : activity.data!.quotes.length === 0 ? (
              <EmptyState icon={FileText} title="Nenhum orçamento para este cliente" />
            ) : (
              <ul className="divide-y divide-neutral-100">
                {activity.data!.quotes.map((q) => (
                  <li key={q.id}>
                    <Link to={`/app/orcamentos/${q.id}`} className="flex flex-wrap items-center gap-3 px-5 py-3 hover:bg-neutral-50">
                      <span className="w-24 text-sm font-medium text-neutral-950 num">{quoteCode(q.number)}</span>
                      <span className="min-w-0 flex-1 truncate text-sm text-neutral-600">{q.vehicle_description || 'Veículo não informado'}</span>
                      <QuoteStatusBadge status={q.status} validUntil={q.valid_until} />
                      <span className="w-28 text-right text-sm font-medium num">{formatCurrency(q.total)}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card>
            <CardHeader title="Ordens de serviço" />
            {activity.data && activity.data.orders.length > 0 ? (
              <ul className="divide-y divide-neutral-100">
                {activity.data.orders.map((o) => (
                  <li key={o.id} className="flex flex-wrap items-center gap-3 px-5 py-3">
                    <span className="w-24 text-sm font-medium text-neutral-950 num">{serviceOrderCode(o.number)}</span>
                    <span className="min-w-0 flex-1 truncate text-sm text-neutral-600">{o.description}</span>
                    <span className="text-xs text-neutral-500">{o.scheduled_at ? formatDateTime(o.scheduled_at) : 'Sem data'}</span>
                    <ServiceStatusBadge status={o.status} />
                  </li>
                ))}
              </ul>
            ) : (
              !activity.isLoading && <EmptyState icon={Wrench} title="Nenhuma ordem de serviço" />
            )}
          </Card>

          <Card>
            <CardHeader title="Simulações" />
            {activity.data && activity.data.simulations.length > 0 ? (
              <ul className="divide-y divide-neutral-100">
                {activity.data.simulations.map((s) => (
                  <li key={s.id} className="flex flex-wrap items-center gap-3 px-5 py-3">
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-neutral-950">{vehicleName(s.vehicle) || 'Veículo removido'}</p>
                      <p className="truncate text-xs text-neutral-500">
                        {ZONES.filter((z) => s.config[z]).map((z) => `${ZONE_SHORT[z]} ${s.config[z]!.vlt}%`).join(' · ')} · {MODE_LABELS[s.mode]}
                      </p>
                    </div>
                    <span className="text-xs text-neutral-500">{formatDateTime(s.created_at)}</span>
                    <Link to={`/app/simulador?simulacao=${s.id}`} className="text-[13px] font-medium text-neutral-900 underline-offset-4 hover:underline">
                      Abrir
                    </Link>
                  </li>
                ))}
              </ul>
            ) : (
              !activity.isLoading && <EmptyState icon={SunDim} title="Nenhuma simulação vinculada" />
            )}
          </Card>
        </div>
      </div>

      <CustomerFormModal open={editing} onClose={() => setEditing(false)} customer={customer} />
    </>
  )
}

function Info({ icon: Icon, label, value }: { icon: typeof Phone; label: string; value: string | null }) {
  return (
    <div className="flex gap-3">
      <Icon className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" strokeWidth={1.6} />
      <div className="min-w-0">
        <p className="text-xs text-neutral-500">{label}</p>
        <p className="break-words text-neutral-900">{value || '—'}</p>
      </div>
    </div>
  )
}
