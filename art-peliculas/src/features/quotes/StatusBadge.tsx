import { CheckCircle2, Clock } from 'lucide-react'
import { Badge, type BadgeTone } from '@/components/ui'
import { QUOTE_STATUS_LABELS, SERVICE_STATUS_LABELS } from '@/lib/constants'
import { todayISO } from '@/lib/format'
import type { QuoteStatus, ServiceOrderStatus } from '@/types/domain'

const QUOTE_TONES: Record<QuoteStatus, BadgeTone> = {
  rascunho: 'dashed',
  enviado: 'outline',
  aprovado: 'solid',
  recusado: 'muted',
  concluido: 'solid',
}

export function isQuoteExpired(q: { status: QuoteStatus; valid_until: string | null }) {
  return (q.status === 'rascunho' || q.status === 'enviado') && !!q.valid_until && q.valid_until < todayISO()
}

export function QuoteStatusBadge({ status, validUntil }: { status: QuoteStatus; validUntil?: string | null }) {
  const expired = isQuoteExpired({ status, valid_until: validUntil ?? null })
  return (
    <span className="inline-flex flex-wrap items-center gap-1">
      <Badge tone={QUOTE_TONES[status]} icon={status === 'concluido' ? <CheckCircle2 className="h-3 w-3" /> : undefined}>
        {QUOTE_STATUS_LABELS[status]}
      </Badge>
      {expired && (
        <Badge tone="subtle" icon={<Clock className="h-3 w-3" />}>
          Vencido
        </Badge>
      )}
    </span>
  )
}

const SERVICE_TONES: Record<ServiceOrderStatus, BadgeTone> = {
  agendado: 'outline',
  em_andamento: 'solid',
  concluido: 'muted',
  cancelado: 'dashed',
}

export function ServiceStatusBadge({ status }: { status: ServiceOrderStatus }) {
  return (
    <Badge tone={SERVICE_TONES[status]} icon={status === 'concluido' ? <CheckCircle2 className="h-3 w-3" /> : undefined}>
      {SERVICE_STATUS_LABELS[status]}
    </Badge>
  )
}
