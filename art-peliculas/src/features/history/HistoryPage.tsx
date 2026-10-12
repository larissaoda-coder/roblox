import { useState } from 'react'
import { Link } from 'react-router-dom'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { ChevronDown, History, Minus, Pencil, Plus } from 'lucide-react'
import { Card, EmptyState, Input, Pagination, Select, Skeleton } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { supabase } from '@/lib/supabase'
import { QUOTE_STATUS_LABELS, ROLE_LABELS, SERVICE_STATUS_LABELS, TABLE_LABELS } from '@/lib/constants'
import { formatDateTime } from '@/lib/format'
import { cn } from '@/lib/cn'
import type { AuditEntry } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { useTeam } from '@/features/services/api'

const PAGE = 30

type Row = AuditEntry & { author: { full_name: string } | null }

const FIELD_LABELS: Record<string, string> = {
  name: 'nome',
  full_name: 'nome',
  role: 'papel',
  active: 'ativo',
  status: 'status',
  total: 'total',
  subtotal: 'subtotal',
  discount_total: 'desconto total',
  discount_value: 'desconto',
  discount_type: 'tipo de desconto',
  price: 'preço',
  base_price: 'preço base',
  vlt_percent: 'transmissão (%)',
  manufacturer: 'fabricante',
  product_line: 'linha',
  brand: 'marca',
  model: 'modelo',
  generation: 'geração',
  category: 'categoria',
  year_start: 'ano inicial',
  year_end: 'ano final',
  document: 'CPF/CNPJ',
  email: 'e-mail',
  phone: 'telefone',
  city: 'cidade',
  state: 'UF',
  notes: 'observações',
  internal_notes: 'anotações internas',
  valid_until: 'validade',
  glass_masks: 'máscaras dos vidros',
  model_3d_path: 'modelo 3D',
  model_3d_glass_map: 'mapeamento 3D',
  is_primary: 'imagem principal',
  scheduled_at: 'agendamento',
  assigned_to: 'responsável',
  max_discount_percent: 'desconto máximo (%)',
  quote_validity_days: 'validade padrão (dias)',
  company_name: 'nome da empresa',
}

const HIDDEN_FIELDS = new Set(['id', 'created_at', 'updated_at', 'created_by', 'updated_by', 'number', 'items_discount', 'discount_authorized_percent'])

function formatValue(key: string, v: unknown): string {
  if (v === null || v === undefined || v === '') return '—'
  if (typeof v === 'boolean') return v ? 'Sim' : 'Não'
  if (key === 'status' && typeof v === 'string') return (QUOTE_STATUS_LABELS as Record<string, string>)[v] ?? (SERVICE_STATUS_LABELS as Record<string, string>)[v] ?? v
  if (key === 'role' && typeof v === 'string') return (ROLE_LABELS as Record<string, string>)[v] ?? v
  if (typeof v === 'object') return 'atualizado'
  if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(v)) return formatDateTime(v)
  const s = String(v)
  return s.length > 80 ? `${s.slice(0, 80)}…` : s
}

function recordLink(e: Row) {
  if (!e.record_id || e.action === 'DELETE') return null
  if (e.table_name === 'customers') return `/app/clientes/${e.record_id}`
  if (e.table_name === 'quotes') return `/app/orcamentos/${e.record_id}`
  if (e.table_name === 'vehicles') return `/app/garagem/${e.record_id}`
  if (e.table_name === 'films') return '/app/peliculas'
  if (e.table_name === 'service_orders' || e.table_name === 'service_types') return '/app/servicos'
  return null
}

const VERBS = { INSERT: 'cadastrou', UPDATE: 'alterou', DELETE: 'excluiu' } as const
const ICONS = { INSERT: Plus, UPDATE: Pencil, DELETE: Minus } as const

export function HistoryPage() {
  const [table, setTable] = useState('')
  const [action, setAction] = useState('')
  const [user, setUser] = useState('')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [page, setPage] = useState(1)
  const [open, setOpen] = useState<number | null>(null)
  const team = useTeam()

  const filters = { table, action, user, from, to, page }
  const { data, isLoading, error, refetch, isFetching } = useQuery({
    queryKey: ['audit', filters],
    placeholderData: keepPreviousData,
    queryFn: async () => {
      let q = supabase
        .from('audit_log')
        .select('*, author:profiles(full_name)', { count: 'exact' })
        .order('changed_at', { ascending: false })
        .range((page - 1) * PAGE, page * PAGE - 1)
      if (table) q = q.eq('table_name', table)
      if (action) q = q.eq('action', action)
      if (user) q = q.eq('changed_by', user)
      if (from) q = q.gte('changed_at', new Date(`${from}T00:00:00`).toISOString())
      if (to) q = q.lte('changed_at', new Date(`${to}T23:59:59`).toISOString())
      const { data, error, count } = await q
      if (error) throw error
      return { rows: data as unknown as Row[], total: count ?? 0 }
    },
  })

  const reset = (fn: () => void) => {
    fn()
    setPage(1)
  }

  return (
    <>
      <PageHeader title="Histórico" description="Registro automático das alterações relevantes: quem fez, quando e o que mudou." />
      <Card>
        <div className="grid gap-3 border-b border-neutral-200 p-4 sm:grid-cols-2 lg:grid-cols-5">
          <Select value={table} onChange={(e) => reset(() => setTable(e.target.value))} aria-label="Filtrar por área">
            <option value="">Todas as áreas</option>
            {Object.entries(TABLE_LABELS).map(([k, v]) => (
              <option key={k} value={k}>
                {v}
              </option>
            ))}
          </Select>
          <Select value={action} onChange={(e) => reset(() => setAction(e.target.value))} aria-label="Filtrar por ação">
            <option value="">Todas as ações</option>
            <option value="INSERT">Cadastros</option>
            <option value="UPDATE">Alterações</option>
            <option value="DELETE">Exclusões</option>
          </Select>
          <Select value={user} onChange={(e) => reset(() => setUser(e.target.value))} aria-label="Filtrar por usuário">
            <option value="">Todos os usuários</option>
            {(team.data ?? []).map((p) => (
              <option key={p.id} value={p.id}>
                {p.full_name}
              </option>
            ))}
          </Select>
          <Input type="date" value={from} onChange={(e) => reset(() => setFrom(e.target.value))} aria-label="Data inicial" />
          <Input type="date" value={to} onChange={(e) => reset(() => setTo(e.target.value))} aria-label="Data final" />
        </div>

        {error ? (
          <ErrorState error={error} onRetry={() => void refetch()} />
        ) : isLoading ? (
          <div className="space-y-2 p-4">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : !data?.rows.length ? (
          <EmptyState icon={History} title="Nenhum registro encontrado" description="Ajuste os filtros ou o período." />
        ) : (
          <ul className={cn('divide-y divide-neutral-100', isFetching && 'opacity-70')}>
            {data.rows.map((e) => {
              const Icon = ICONS[e.action]
              const changes =
                e.action === 'UPDATE'
                  ? Object.keys(e.new_data ?? {})
                      .filter((k) => !HIDDEN_FIELDS.has(k))
                      .map((k) => ({ key: k, label: FIELD_LABELS[k] ?? k.replace(/_/g, ' '), from: e.old_data?.[k], to: e.new_data?.[k] }))
                  : []
              const link = recordLink(e)
              const expanded = open === e.id
              return (
                <li key={e.id} className="px-4 py-3 sm:px-5">
                  <div className="flex items-start gap-3">
                    <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-neutral-200 bg-neutral-50 text-neutral-700">
                      <Icon className="h-3.5 w-3.5" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="text-sm text-neutral-800">
                        <span className="font-medium text-neutral-950">{e.author?.full_name ?? 'Sistema'}</span> {VERBS[e.action]}{' '}
                        {(TABLE_LABELS[e.table_name] ?? e.table_name).toLowerCase()}{' '}
                        {link ? (
                          <Link to={link} className="font-medium text-neutral-950 underline-offset-4 hover:underline">
                            {e.record_label}
                          </Link>
                        ) : (
                          <span className="font-medium text-neutral-950">{e.record_label}</span>
                        )}
                      </p>
                      {changes.length > 0 && (
                        <p className="mt-0.5 truncate text-xs text-neutral-500">Campos: {changes.map((c) => c.label).join(', ')}</p>
                      )}
                    </div>
                    <span className="shrink-0 text-xs text-neutral-500 num">{formatDateTime(e.changed_at)}</span>
                    {changes.length > 0 && (
                      <button
                        type="button"
                        onClick={() => setOpen(expanded ? null : e.id)}
                        className="rounded p-1 text-neutral-500 hover:bg-neutral-100 hover:text-neutral-900"
                        aria-expanded={expanded}
                        aria-label="Ver detalhes"
                      >
                        <ChevronDown className={cn('h-4 w-4 transition-transform', expanded && 'rotate-180')} />
                      </button>
                    )}
                  </div>
                  {expanded && (
                    <dl className="ml-10 mt-3 grid animate-fade-in gap-1.5 rounded-md bg-neutral-50 p-3 text-xs">
                      {changes.map((c) => (
                        <div key={c.key} className="grid grid-cols-[140px_1fr] gap-3">
                          <dt className="text-neutral-500">{c.label}</dt>
                          <dd className="text-neutral-800">
                            <span className="text-neutral-500 line-through decoration-neutral-400">{formatValue(c.key, c.from)}</span>
                            <span className="mx-1.5 text-neutral-400">→</span>
                            <span className="font-medium">{formatValue(c.key, c.to)}</span>
                          </dd>
                        </div>
                      ))}
                    </dl>
                  )}
                </li>
              )
            })}
          </ul>
        )}
        <Pagination page={page} pageSize={PAGE} total={data?.total ?? 0} onPageChange={setPage} />
      </Card>
    </>
  )
}
