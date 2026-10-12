import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Car, CheckCircle2, FileText, Pencil, Printer, SunDim, Trash2, Wrench } from 'lucide-react'
import { Button, Card, CardBody, CardHeader, EmptyState, Field, Modal, PageLoader, Textarea, useConfirm, useToast } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { ITEM_KIND_LABELS, QUOTE_STATUS_LABELS, QUOTE_TRANSITIONS, ZONES, ZONE_SHORT } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import {
  formatCurrency,
  formatDate,
  formatDateTime,
  formatDocument,
  formatNumber,
  formatPercent,
  formatPhone,
  formatPlate,
  quoteCode,
  serviceOrderCode,
} from '@/lib/format'
import type { QuoteStatus } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { ServiceOrderFormModal } from '@/features/services/ServiceOrderFormModal'
import { isQuoteExpired, QuoteStatusBadge, ServiceStatusBadge } from './StatusBadge'
import { useDeleteQuote, useQuote, useSetQuoteStatus } from './api'

const ACTION_LABELS: Record<QuoteStatus, string> = {
  rascunho: 'Voltar para rascunho',
  enviado: 'Marcar como enviado',
  aprovado: 'Aprovar',
  recusado: 'Recusar',
  concluido: 'Concluir',
}

export function QuoteDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { can } = useAuth()
  const { data: q, isLoading, error, refetch } = useQuote(id)
  const setStatus = useSetQuoteStatus()
  const del = useDeleteQuote()
  const confirm = useConfirm()
  const toast = useToast()
  const [pending, setPending] = useState<QuoteStatus | null>(null)
  const [note, setNote] = useState('')
  const [creatingOrder, setCreatingOrder] = useState(false)

  if (isLoading) return <PageLoader />
  if (error) return <ErrorState error={error} onRetry={() => void refetch()} />
  if (!q) return <EmptyState icon={FileText} title="Orçamento não encontrado" className="py-24" />

  const canManage = can('orcamentos.gerenciar')
  const editable = canManage && (q.status === 'rascunho' || q.status === 'enviado' || q.status === 'recusado')
  const transitions = QUOTE_TRANSITIONS[q.status]
  const discountPct = q.subtotal > 0 ? (q.discount_total / q.subtotal) * 100 : 0

  const applyStatus = async () => {
    if (!pending) return
    try {
      await setStatus.mutateAsync({ id: q.id, status: pending, note: note.trim() || undefined })
      toast.success(`Status alterado para ${QUOTE_STATUS_LABELS[pending].toLowerCase()}.`)
      setPending(null)
      setNote('')
    } catch (err) {
      toast.error(toMessage(err))
    }
  }

  const onDelete = async () => {
    const ok = await confirm({ title: `Excluir ${quoteCode(q.number)}?`, description: 'O orçamento e seus itens serão removidos definitivamente.', destructive: true })
    if (!ok) return
    try {
      await del.mutateAsync(q.id)
      toast.success('Orçamento excluído.')
      navigate('/app/orcamentos')
    } catch (err) {
      toast.error(toMessage(err))
    }
  }

  return (
    <>
      <PageHeader
        backTo="/app/orcamentos"
        backLabel="Orçamentos"
        eyebrow={`Criado em ${formatDateTime(q.created_at)}${q.author ? ` por ${q.author.full_name}` : ''}`}
        title={
          <span className="flex flex-wrap items-center gap-3">
            {quoteCode(q.number)} <QuoteStatusBadge status={q.status} validUntil={q.valid_until} />
          </span>
        }
        description={q.customer ? <Link to={`/app/clientes/${q.customer.id}`} className="font-medium text-neutral-800 underline-offset-4 hover:underline">{q.customer.name}</Link> : 'Cliente removido'}
        actions={
          <>
            <Button variant="secondary" icon={<Printer className="h-4 w-4" />} onClick={() => window.open(`/app/orcamentos/${q.id}/imprimir`, '_blank', 'noopener')}>
              Imprimir
            </Button>
            {editable && (
              <Button variant="secondary" icon={<Pencil className="h-4 w-4" />} onClick={() => navigate(`/app/orcamentos/${q.id}/editar`)}>
                Editar
              </Button>
            )}
            {can('orcamentos.excluir') && (
              <Button variant="ghost" size="icon" aria-label="Excluir orçamento" onClick={onDelete}>
                <Trash2 className="h-4 w-4" />
              </Button>
            )}
          </>
        }
      />

      {canManage && transitions.length > 0 && (
        <Card className="mb-6">
          <CardBody className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="text-sm text-neutral-600">
              {isQuoteExpired(q) ? (
                <span className="font-medium text-neutral-950">Validade encerrada em {formatDate(q.valid_until)}. </span>
              ) : q.valid_until ? (
                <span>Válido até {formatDate(q.valid_until)}. </span>
              ) : null}
              Acompanhe o andamento alterando o status.
            </div>
            <div className="flex flex-wrap gap-2">
              {transitions.map((s) => (
                <Button key={s} size="sm" variant={s === 'aprovado' || s === 'concluido' ? 'primary' : 'secondary'} onClick={() => setPending(s)}>
                  {ACTION_LABELS[s]}
                </Button>
              ))}
              {q.status === 'aprovado' && can('servicos.gerenciar') && (
                <Button size="sm" variant="outline-dark" icon={<Wrench className="h-3.5 w-3.5" />} onClick={() => setCreatingOrder(true)}>
                  Gerar ordem de serviço
                </Button>
              )}
            </div>
          </CardBody>
        </Card>
      )}

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_340px]">
        <div className="min-w-0 space-y-6">
          <Card>
            <CardHeader title="Itens" />
            <div className="scrollbar-thin relative overflow-x-auto">
              <table className="w-full min-w-[560px] text-sm">
                <thead>
                  <tr className="border-b border-neutral-200 bg-neutral-50/80 text-[11.5px] uppercase tracking-wide text-neutral-500">
                    <th className="px-5 py-2.5 text-left font-semibold">Descrição</th>
                    <th className="px-3 py-2.5 text-right font-semibold">Qtd.</th>
                    <th className="px-3 py-2.5 text-right font-semibold">Unitário</th>
                    <th className="px-3 py-2.5 text-right font-semibold">Desconto</th>
                    <th className="px-5 py-2.5 text-right font-semibold">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-neutral-100">
                  {q.quote_items.map((i) => (
                    <tr key={i.id}>
                      <td className="px-5 py-3">
                        <p className="text-neutral-950">{i.description}</p>
                        <p className="text-xs text-neutral-500">
                          {ITEM_KIND_LABELS[i.kind]}
                          {i.glass_zones.length > 0 && ` · ${ZONES.filter((z) => i.glass_zones.includes(z)).map((z) => ZONE_SHORT[z]).join(', ')}`}
                        </p>
                      </td>
                      <td className="px-3 py-3 text-right num">{formatNumber(i.quantity)}</td>
                      <td className="px-3 py-3 text-right num">{formatCurrency(i.unit_price)}</td>
                      <td className="px-3 py-3 text-right text-neutral-600 num">{i.discount ? `− ${formatCurrency(i.discount)}` : '—'}</td>
                      <td className="px-5 py-3 text-right font-medium num">{formatCurrency(i.total)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="border-t border-neutral-200 px-5 py-4">
              <dl className="ml-auto max-w-xs space-y-1.5 text-sm">
                <div className="flex justify-between">
                  <dt className="text-neutral-600">Subtotal</dt>
                  <dd className="num">{formatCurrency(q.subtotal)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-neutral-600">Descontos</dt>
                  <dd className="num">− {formatCurrency(q.discount_total)}</dd>
                </div>
                <div className="flex justify-between border-t border-neutral-200 pt-2 text-base font-semibold">
                  <dt>Total</dt>
                  <dd className="num">{formatCurrency(q.total)}</dd>
                </div>
                {q.discount_total > 0 && (
                  <p className="pt-1 text-right text-xs text-neutral-500">
                    Desconto de {formatPercent(Math.round(discountPct * 100) / 100)}
                    {q.authorizer ? ` · autorizado por ${q.authorizer.full_name}` : ''}
                  </p>
                )}
              </dl>
            </div>
          </Card>

          {(q.notes || q.internal_notes) && (
            <Card>
              <CardHeader title="Observações" />
              <CardBody className="grid gap-5 md:grid-cols-2">
                <div>
                  <p className="eyebrow mb-1.5">Impressas no orçamento</p>
                  <p className="whitespace-pre-line text-sm text-neutral-700">{q.notes || '—'}</p>
                </div>
                <div>
                  <p className="eyebrow mb-1.5">Internas</p>
                  <p className="whitespace-pre-line text-sm text-neutral-700">{q.internal_notes || '—'}</p>
                </div>
              </CardBody>
            </Card>
          )}

          <Card>
            <CardHeader title="Ordens de serviço" />
            {q.service_orders.length === 0 ? (
              <EmptyState icon={Wrench} title="Nenhuma ordem de serviço" description={q.status === 'aprovado' ? 'Gere a ordem de serviço para agendar a instalação.' : 'Disponível após a aprovação do orçamento.'} />
            ) : (
              <ul className="divide-y divide-neutral-100">
                {q.service_orders.map((o) => (
                  <li key={o.id} className="flex flex-wrap items-center gap-3 px-5 py-3 text-sm">
                    <span className="w-24 font-medium num">{serviceOrderCode(o.number)}</span>
                    <span className="min-w-0 flex-1 truncate text-neutral-600">{o.description}</span>
                    <span className="text-xs text-neutral-500">{o.scheduled_at ? formatDateTime(o.scheduled_at) : 'Sem data'}</span>
                    <ServiceStatusBadge status={o.status} />
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>

        <aside className="space-y-6">
          <Card>
            <CardHeader title="Cliente e veículo" />
            <CardBody className="space-y-3 text-sm">
              {q.customer && (
                <div>
                  <p className="font-medium text-neutral-950">{q.customer.name}</p>
                  <p className="text-xs text-neutral-500">
                    {[q.customer.document ? formatDocument(q.customer.document) : null, q.customer.phone ? formatPhone(q.customer.phone) : null, q.customer.email]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                </div>
              )}
              <div className="flex items-start gap-2 border-t border-neutral-100 pt-3">
                <Car className="mt-0.5 h-4 w-4 text-neutral-400" />
                <div>
                  <p className="text-neutral-900">{q.vehicle_description || 'Veículo não informado'}</p>
                  <p className="text-xs text-neutral-500">{[q.vehicle_plate ? formatPlate(q.vehicle_plate) : null, q.vehicle_year, q.vehicle_color].filter(Boolean).join(' · ')}</p>
                </div>
              </div>
              {q.simulation && (
                <div className="flex items-start gap-2 border-t border-neutral-100 pt-3">
                  <SunDim className="mt-0.5 h-4 w-4 text-neutral-400" />
                  <div className="min-w-0">
                    <p className="text-neutral-900">Simulação vinculada</p>
                    <p className="text-xs text-neutral-500">
                      {ZONES.filter((z) => q.simulation!.config[z]).map((z) => `${ZONE_SHORT[z]} ${q.simulation!.config[z]!.vlt}%`).join(' · ')}
                    </p>
                    <Link to={`/app/simulador?simulacao=${q.simulation.id}`} className="text-xs font-medium text-neutral-900 underline-offset-4 hover:underline">
                      Abrir no simulador
                    </Link>
                  </div>
                </div>
              )}
            </CardBody>
          </Card>

          <Card>
            <CardHeader title="Linha do tempo" />
            <CardBody>
              <ol className="relative space-y-4 border-l border-neutral-200 pl-5">
                {q.quote_events.map((e) => (
                  <li key={e.id} className="relative">
                    <span className="absolute -left-[25px] top-1 flex h-2.5 w-2.5 rounded-full border-2 border-white bg-neutral-900 ring-1 ring-neutral-300" />
                    <p className="text-sm text-neutral-900">
                      {e.event === 'criado' && 'Orçamento criado'}
                      {e.event === 'atualizado' && 'Itens ou valores atualizados'}
                      {e.event === 'status' && e.status && (
                        <>
                          Status alterado para <span className="font-medium">{QUOTE_STATUS_LABELS[e.status]}</span>
                        </>
                      )}
                    </p>
                    {e.note && <p className="mt-0.5 text-xs text-neutral-600">“{e.note}”</p>}
                    <p className="mt-0.5 text-xs text-neutral-500">
                      {formatDateTime(e.created_at)}
                      {e.author ? ` · ${e.author.full_name}` : ''}
                    </p>
                  </li>
                ))}
                {q.status === 'concluido' && (
                  <li className="relative">
                    <CheckCircle2 className="absolute -left-[27px] top-0.5 h-3.5 w-3.5 bg-white text-neutral-900" />
                    <p className="text-sm font-medium text-neutral-900">Concluído</p>
                  </li>
                )}
              </ol>
            </CardBody>
          </Card>
        </aside>
      </div>

      <Modal
        open={pending !== null}
        onClose={() => setPending(null)}
        title={pending ? ACTION_LABELS[pending] : ''}
        description={`${quoteCode(q.number)} · ${q.customer?.name ?? ''}`}
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setPending(null)}>
              Cancelar
            </Button>
            <Button onClick={applyStatus} loading={setStatus.isPending}>
              Confirmar
            </Button>
          </>
        }
      >
        <Field label="Observação (opcional)" hint="Fica registrada na linha do tempo.">
          <Textarea rows={3} value={note} onChange={(e) => setNote(e.target.value)} maxLength={500} />
        </Field>
      </Modal>

      <ServiceOrderFormModal
        open={creatingOrder}
        onClose={() => setCreatingOrder(false)}
        prefill={{
          quote_id: q.id,
          quote_number: q.number,
          customer_id: q.customer_id,
          customer_name: q.customer?.name,
          vehicle_id: q.vehicle_id,
          vehicle_description: q.vehicle_id ? '' : q.vehicle_description,
          vehicle_plate: q.vehicle_plate,
          description: q.quote_items.map((i) => i.description).join('; ').slice(0, 500),
          price: q.total,
        }}
        onSaved={() => void refetch()}
      />
    </>
  )
}
