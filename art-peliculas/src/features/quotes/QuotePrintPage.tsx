import { useEffect } from 'react'
import { Link, useParams, useSearchParams } from 'react-router-dom'
import { ArrowLeft, Printer } from 'lucide-react'
import { Button, PageLoader } from '@/components/ui'
import { Logo } from '@/components/layout/Logo'
import { ZONES, ZONE_LABELS } from '@/lib/constants'
import {
  formatCurrency,
  formatDate,
  formatDocument,
  formatLongDate,
  formatNumber,
  formatPercent,
  formatPhone,
  formatPlate,
  formatZip,
  quoteCode,
} from '@/lib/format'
import { useSignedUrl } from '@/lib/storage'
import { useSettings } from '@/features/settings/api'
import { ErrorState } from '@/features/shared/ErrorState'
import { useQuote } from './api'
import { QUOTE_STATUS_LABELS } from '@/lib/constants'

/** Versão para impressão (A4) do orçamento, com os dados da empresa definidos nas configurações. */
export function QuotePrintPage() {
  const { id } = useParams()
  const [params] = useSearchParams()
  const { data: q, isLoading, error } = useQuote(id)
  const settings = useSettings()
  const { url: logoUrl } = useSignedUrl(settings.data?.logo_path)
  const s = settings.data

  useEffect(() => {
    if (q) document.title = `${quoteCode(q.number)} · ${q.customer?.name ?? ''}`
  }, [q])
  useEffect(() => {
    if (q && s && params.get('auto') === '1') {
      const t = window.setTimeout(() => window.print(), 600)
      return () => window.clearTimeout(t)
    }
  }, [q, s, params])

  if (isLoading || settings.isLoading) return <PageLoader />
  if (error || !q) return <ErrorState error={error ?? new Error('Orçamento não encontrado.')} />

  const c = q.customer
  const address = c
    ? [[c.street, c.address_number].filter(Boolean).join(', '), c.complement, c.district, [c.city, c.state].filter(Boolean).join(' / '), c.zip_code ? `CEP ${formatZip(c.zip_code)}` : '']
        .filter(Boolean)
        .join(' · ')
    : ''
  const discountPct = q.subtotal > 0 ? (q.discount_total / q.subtotal) * 100 : 0

  return (
    <div className="min-h-screen bg-neutral-100 py-8 print:bg-white print:py-0">
      <div className="no-print mx-auto mb-4 flex max-w-[210mm] items-center justify-between px-4">
        <Link to={`/app/orcamentos/${q.id}`} className="inline-flex items-center gap-1.5 text-sm font-medium text-neutral-600 hover:text-neutral-950">
          <ArrowLeft className="h-4 w-4" /> Voltar ao orçamento
        </Link>
        <Button icon={<Printer className="h-4 w-4" />} onClick={() => window.print()}>
          Imprimir / salvar PDF
        </Button>
      </div>

      <article className="mx-auto max-w-[210mm] bg-white px-[14mm] py-[14mm] text-[12.5px] leading-relaxed text-neutral-900 shadow-lift print:max-w-none print:p-0 print:shadow-none">
        <header className="flex items-start justify-between gap-6 border-b border-neutral-900 pb-5">
          <div className="flex items-center gap-4">
            {logoUrl ? <img src={logoUrl} alt={s?.company_name} className="h-14 w-auto max-w-[160px] object-contain" /> : <Logo />}
            {logoUrl && <p className="text-base font-semibold">{s?.company_name}</p>}
          </div>
          <div className="text-right text-[11.5px] text-neutral-600">
            {s?.legal_name && <p className="font-medium text-neutral-900">{s.legal_name}</p>}
            {s?.document && <p>CNPJ/CPF {formatDocument(s.document)}</p>}
            {s?.address && <p>{s.address}</p>}
            <p>{[s?.phone, s?.email, s?.website].filter(Boolean).join(' · ')}</p>
          </div>
        </header>

        <section className="mt-6 flex items-end justify-between gap-6">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-neutral-500">Orçamento</p>
            <h1 className="text-2xl font-semibold tracking-tight num">{quoteCode(q.number)}</h1>
          </div>
          <div className="text-right text-[11.5px]">
            <p>Emitido em {formatLongDate(q.created_at)}</p>
            <p className="font-medium">Válido até {formatDate(q.valid_until)}</p>
            <p className="text-neutral-500">Status: {QUOTE_STATUS_LABELS[q.status]}</p>
          </div>
        </section>

        <section className="mt-6 grid grid-cols-2 gap-6">
          <div className="rounded-md border border-neutral-300 p-4">
            <p className="mb-1 text-[10.5px] font-semibold uppercase tracking-[0.14em] text-neutral-500">Cliente</p>
            <p className="font-semibold">{c?.name}</p>
            {c?.document && <p>CPF/CNPJ {formatDocument(c.document)}</p>}
            <p>{[c?.phone ? formatPhone(c.phone) : null, c?.email].filter(Boolean).join(' · ')}</p>
            {address && <p className="text-neutral-600">{address}</p>}
          </div>
          <div className="rounded-md border border-neutral-300 p-4">
            <p className="mb-1 text-[10.5px] font-semibold uppercase tracking-[0.14em] text-neutral-500">Veículo</p>
            <p className="font-semibold">{q.vehicle_description || 'Não informado'}</p>
            <p>{[q.vehicle_plate ? `Placa ${formatPlate(q.vehicle_plate)}` : null, q.vehicle_year ? `Ano ${q.vehicle_year}` : null, q.vehicle_color].filter(Boolean).join(' · ')}</p>
            {q.simulation && (
              <p className="mt-1 text-neutral-600">
                Simulação:{' '}
                {ZONES.filter((z) => q.simulation!.config[z])
                  .map((z) => `${ZONE_LABELS[z]} ${q.simulation!.config[z]!.vlt}%`)
                  .join('; ')}
              </p>
            )}
          </div>
        </section>

        <table className="mt-6 w-full border-collapse text-[12px]">
          <thead>
            <tr className="border-y border-neutral-900 text-left text-[10.5px] uppercase tracking-[0.1em]">
              <th className="py-2 pr-2 font-semibold">Descrição</th>
              <th className="px-2 py-2 text-right font-semibold">Qtd.</th>
              <th className="px-2 py-2 text-right font-semibold">Unitário</th>
              <th className="px-2 py-2 text-right font-semibold">Desconto</th>
              <th className="py-2 pl-2 text-right font-semibold">Total</th>
            </tr>
          </thead>
          <tbody>
            {q.quote_items.map((i) => (
              <tr key={i.id} className="border-b border-neutral-200 align-top">
                <td className="py-2 pr-2">{i.description}</td>
                <td className="px-2 py-2 text-right num">{formatNumber(i.quantity)}</td>
                <td className="px-2 py-2 text-right num">{formatCurrency(i.unit_price)}</td>
                <td className="px-2 py-2 text-right num">{i.discount ? formatCurrency(i.discount) : '—'}</td>
                <td className="py-2 pl-2 text-right font-medium num">{formatCurrency(i.total)}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <section className="mt-4 flex justify-end">
          <dl className="w-64 space-y-1">
            <div className="flex justify-between">
              <dt>Subtotal</dt>
              <dd className="num">{formatCurrency(q.subtotal)}</dd>
            </div>
            <div className="flex justify-between">
              <dt>Descontos{q.discount_total > 0 ? ` (${formatPercent(Math.round(discountPct * 100) / 100)})` : ''}</dt>
              <dd className="num">− {formatCurrency(q.discount_total)}</dd>
            </div>
            <div className="flex justify-between border-t border-neutral-900 pt-1.5 text-[15px] font-semibold">
              <dt>Total</dt>
              <dd className="num">{formatCurrency(q.total)}</dd>
            </div>
          </dl>
        </section>

        {q.notes && (
          <section className="mt-8 break-inside-avoid">
            <p className="mb-1 text-[10.5px] font-semibold uppercase tracking-[0.14em] text-neutral-500">Observações e condições</p>
            <p className="whitespace-pre-line">{q.notes}</p>
          </section>
        )}

        <section className="mt-16 grid break-inside-avoid grid-cols-2 gap-12 text-center text-[11px] text-neutral-600">
          <div className="border-t border-neutral-500 pt-2">{s?.company_name}</div>
          <div className="border-t border-neutral-500 pt-2">{c?.name} — de acordo</div>
        </section>
      </article>
    </div>
  )
}
