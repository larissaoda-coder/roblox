import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ArrowUpRight, CalendarClock, FileText, Plus, SunDim, Users, Wrench } from 'lucide-react'
import { Button, Card, CardHeader, EmptyState, Skeleton } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { supabase } from '@/lib/supabase'
import { MODE_LABELS, ZONES, ZONE_SHORT } from '@/lib/constants'
import { formatCurrency, formatDateTime, formatNumber, formatRelative, quoteCode, serviceOrderCode, vehicleName } from '@/lib/format'
import type { DashboardStats, QuoteStatus, ServiceOrderStatus, SimulationConfig, SimulationMode } from '@/types/domain'
import { StatTile } from '@/features/shared/StatTile'
import { ErrorState } from '@/features/shared/ErrorState'
import { QuoteStatusBadge, ServiceStatusBadge } from '@/features/quotes/StatusBadge'

interface RecentSimulation {
  id: string
  created_at: string
  mode: SimulationMode
  config: SimulationConfig
  vehicle: { brand: string; model: string; generation: string } | null
  customer: { name: string } | null
  author: { full_name: string } | null
}

interface RecentQuote {
  id: string
  number: number
  status: QuoteStatus
  total: number
  valid_until: string | null
  created_at: string
  customer: { name: string } | null
}

interface UpcomingOrder {
  id: string
  number: number
  status: ServiceOrderStatus
  scheduled_at: string | null
  description: string
  vehicle_description: string
  customer: { name: string } | null
}

function useDashboard() {
  const stats = useQuery({
    queryKey: ['dashboard', 'stats'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('dashboard_stats')
      if (error) throw error
      return data as DashboardStats
    },
  })
  const simulations = useQuery({
    queryKey: ['dashboard', 'simulations'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('simulations')
        .select('id, created_at, mode, config, vehicle:vehicles(brand, model, generation), customer:customers(name), author:profiles(full_name)')
        .order('created_at', { ascending: false })
        .limit(5)
      if (error) throw error
      return data as unknown as RecentSimulation[]
    },
  })
  const quotes = useQuery({
    queryKey: ['dashboard', 'quotes'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('quotes')
        .select('id, number, status, total, valid_until, created_at, customer:customers(name)')
        .order('created_at', { ascending: false })
        .limit(6)
      if (error) throw error
      return data as unknown as RecentQuote[]
    },
  })
  const orders = useQuery({
    queryKey: ['dashboard', 'orders'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('service_orders')
        .select('id, number, status, scheduled_at, description, vehicle_description, customer:customers(name)')
        .in('status', ['agendado', 'em_andamento'])
        .order('scheduled_at', { ascending: true, nullsFirst: false })
        .limit(5)
      if (error) throw error
      return data as unknown as UpcomingOrder[]
    },
  })
  return { stats, simulations, quotes, orders }
}

function greeting() {
  const h = new Date().getHours()
  if (h < 12) return 'Bom dia'
  if (h < 18) return 'Boa tarde'
  return 'Boa noite'
}

function summarizeConfig(config: SimulationConfig) {
  const parts = ZONES.filter((z) => config[z] && config[z]!.vlt < 100).map((z) => `${ZONE_SHORT[z]} ${config[z]!.vlt}%`)
  return parts.length ? parts.join(' · ') : 'Sem película aplicada'
}

export function DashboardPage() {
  const { profile, can } = useAuth()
  const navigate = useNavigate()
  const { stats, simulations, quotes, orders } = useDashboard()
  const s = stats.data

  return (
    <>
      <PageHeader
        eyebrow="Visão geral"
        title={`${greeting()}, ${profile?.full_name.split(' ')[0] ?? ''}`}
        description="Resumo das atividades da Art Películas com dados atualizados do sistema."
        actions={
          <>
            <Button variant="secondary" icon={<SunDim className="h-4 w-4" />} onClick={() => navigate('/app/simulador')}>
              Nova simulação
            </Button>
            {can('orcamentos.gerenciar') && (
              <Button icon={<Plus className="h-4 w-4" />} onClick={() => navigate('/app/orcamentos/novo')}>
                Novo orçamento
              </Button>
            )}
          </>
        }
      />

      {stats.error ? (
        <Card className="mb-6">
          <ErrorState error={stats.error} onRetry={() => void stats.refetch()} />
        </Card>
      ) : (
        <section aria-label="Indicadores" className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <StatTile
            label="Clientes cadastrados"
            icon={Users}
            to="/app/clientes"
            loading={stats.isLoading}
            value={formatNumber(s?.customers_total)}
            context={`${formatNumber(s?.customers_month)} novos neste mês`}
          />
          <StatTile
            label="Orçamentos pendentes"
            icon={FileText}
            to="/app/orcamentos?status=pendentes"
            loading={stats.isLoading}
            value={formatNumber(s?.quotes_pending)}
            context={`${formatCurrency(s?.quotes_pending_value)} em negociação`}
          />
          <StatTile
            label="Serviços registrados"
            icon={Wrench}
            to="/app/servicos"
            loading={stats.isLoading}
            value={formatNumber(s?.service_orders_total)}
            context={`${formatNumber(s?.service_orders_open)} em aberto · ${formatNumber(s?.service_orders_done_month)} concluídos no mês`}
          />
          <StatTile
            label="Simulações realizadas"
            icon={SunDim}
            to="/app/simulador"
            loading={stats.isLoading}
            value={formatNumber(s?.simulations_total)}
            context={`${formatNumber(s?.simulations_week)} nos últimos 7 dias`}
          />
        </section>
      )}

      {!stats.isLoading && s && (
        <p className="mt-4 text-xs text-neutral-500">
          Aprovados neste mês: <span className="font-medium text-neutral-800">{formatNumber(s.quotes_approved_month)}</span> orçamentos ·{' '}
          <span className="font-medium text-neutral-800">{formatCurrency(s.quotes_approved_month_value)}</span>. Garagem com{' '}
          {formatNumber(s.vehicles_total)} veículos e catálogo com {formatNumber(s.films_total)} películas ativas.
        </p>
      )}

      <div className="mt-8 grid gap-6 xl:grid-cols-[1.35fr_1fr]">
        <Card>
          <CardHeader
            title="Orçamentos recentes"
            actions={
              <Link to="/app/orcamentos" className="inline-flex items-center gap-1 text-[13px] font-medium text-neutral-600 hover:text-neutral-950">
                Ver todos <ArrowUpRight className="h-3.5 w-3.5" />
              </Link>
            }
          />
          {quotes.isLoading ? (
            <ListSkeleton />
          ) : quotes.error ? (
            <ErrorState error={quotes.error} onRetry={() => void quotes.refetch()} />
          ) : quotes.data && quotes.data.length > 0 ? (
            <ul className="divide-y divide-neutral-100">
              {quotes.data.map((q) => (
                <li key={q.id}>
                  <Link to={`/app/orcamentos/${q.id}`} className="flex items-center gap-4 px-5 py-3.5 transition-colors hover:bg-neutral-50">
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-neutral-950">{q.customer?.name ?? 'Cliente removido'}</p>
                      <p className="text-xs text-neutral-500">
                        {quoteCode(q.number)} · {formatRelative(q.created_at)}
                      </p>
                      <div className="mt-1.5 sm:hidden">
                        <QuoteStatusBadge status={q.status} validUntil={q.valid_until} />
                      </div>
                    </div>
                    <div className="hidden sm:block">
                      <QuoteStatusBadge status={q.status} validUntil={q.valid_until} />
                    </div>
                    <p className="text-right text-sm font-medium text-neutral-950 num sm:w-28">{formatCurrency(q.total)}</p>
                  </Link>
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState icon={FileText} title="Nenhum orçamento ainda" description="Os orçamentos criados aparecerão aqui." />
          )}
        </Card>

        <Card>
          <CardHeader
            title="Simulações recentes"
            actions={
              <Link to="/app/simulador" className="inline-flex items-center gap-1 text-[13px] font-medium text-neutral-600 hover:text-neutral-950">
                Abrir simulador <ArrowUpRight className="h-3.5 w-3.5" />
              </Link>
            }
          />
          {simulations.isLoading ? (
            <ListSkeleton />
          ) : simulations.error ? (
            <ErrorState error={simulations.error} onRetry={() => void simulations.refetch()} />
          ) : simulations.data && simulations.data.length > 0 ? (
            <ul className="divide-y divide-neutral-100">
              {simulations.data.map((sim) => (
                <li key={sim.id} className="px-5 py-3.5">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium text-neutral-950">{vehicleName(sim.vehicle) || 'Veículo removido'}</p>
                      <p className="mt-0.5 truncate text-xs text-neutral-500">{summarizeConfig(sim.config)}</p>
                    </div>
                    <span className="shrink-0 text-xs text-neutral-400">{formatRelative(sim.created_at)}</span>
                  </div>
                  <p className="mt-1 text-xs text-neutral-500">
                    {MODE_LABELS[sim.mode]}
                    {sim.customer ? ` · ${sim.customer.name}` : ''}
                    {sim.author ? ` · por ${sim.author.full_name}` : ''}
                  </p>
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState icon={SunDim} title="Nenhuma simulação salva" description="Salve simulações no simulador para acompanhá-las aqui." />
          )}
        </Card>
      </div>

      <Card className="mt-6">
        <CardHeader
          title="Próximos serviços"
          description="Ordens de serviço agendadas ou em andamento"
          actions={
            <Link to="/app/servicos" className="inline-flex items-center gap-1 text-[13px] font-medium text-neutral-600 hover:text-neutral-950">
              Ver agenda <ArrowUpRight className="h-3.5 w-3.5" />
            </Link>
          }
        />
        {orders.isLoading ? (
          <ListSkeleton />
        ) : orders.error ? (
          <ErrorState error={orders.error} onRetry={() => void orders.refetch()} />
        ) : orders.data && orders.data.length > 0 ? (
          <ul className="divide-y divide-neutral-100">
            {orders.data.map((o) => (
              <li key={o.id} className="flex flex-col gap-2 px-5 py-3.5 sm:flex-row sm:items-center sm:gap-4">
                <div className="flex items-center gap-2 text-sm text-neutral-700 sm:w-48">
                  <CalendarClock className="h-4 w-4 text-neutral-400" strokeWidth={1.6} />
                  {o.scheduled_at ? formatDateTime(o.scheduled_at) : 'Sem data'}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-neutral-950">
                    {serviceOrderCode(o.number)} · {o.customer?.name ?? '—'}
                  </p>
                  <p className="truncate text-xs text-neutral-500">{[o.vehicle_description, o.description].filter(Boolean).join(' · ')}</p>
                </div>
                <ServiceStatusBadge status={o.status} />
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState icon={Wrench} title="Nenhum serviço agendado" description="Gere ordens de serviço a partir de orçamentos aprovados." />
        )}
      </Card>
    </>
  )
}

function ListSkeleton() {
  return (
    <div className="space-y-3 p-5">
      {Array.from({ length: 4 }).map((_, i) => (
        <Skeleton key={i} className="h-10 w-full" />
      ))}
    </div>
  )
}
