import type { DiscountType } from '@/types/domain'

export interface CalcItem {
  quantity: number
  unit_price: number
  discount: number
}

export interface QuoteTotals {
  subtotal: number
  itemsDiscount: number
  quoteDiscount: number
  discountTotal: number
  total: number
  /** Desconto total em relação ao subtotal (%). */
  discountPercent: number
}

export function round2(value: number) {
  return Math.round((value + Number.EPSILON) * 100) / 100
}

export function itemGross(item: Pick<CalcItem, 'quantity' | 'unit_price'>) {
  return round2((Number(item.quantity) || 0) * (Number(item.unit_price) || 0))
}

export function itemTotal(item: CalcItem) {
  return round2(itemGross(item) - (Number(item.discount) || 0))
}

/** Mesmo cálculo de public.save_quote — o servidor recalcula e é a fonte oficial. */
export function computeQuoteTotals(items: CalcItem[], discountType: DiscountType, discountValue: number): QuoteTotals {
  const subtotal = round2(items.reduce((acc, i) => acc + itemGross(i), 0))
  const itemsDiscount = round2(items.reduce((acc, i) => acc + round2(Number(i.discount) || 0), 0))
  const net = round2(subtotal - itemsDiscount)
  const value = Number(discountValue) || 0
  const quoteDiscount = discountType === 'percentual' ? round2((net * value) / 100) : round2(value)
  const discountTotal = round2(itemsDiscount + quoteDiscount)
  const total = round2(subtotal - discountTotal)
  const discountPercent = subtotal > 0 ? Math.round((discountTotal / subtotal) * 100 * 10000) / 10000 : 0
  return { subtotal, itemsDiscount, quoteDiscount, discountTotal, total, discountPercent }
}

export interface DiscountCheck {
  ok: boolean
  message?: string
}

export function checkDiscount(
  totals: QuoteTotals,
  opts: { maxPercent: number; canExceed: boolean; authorizedPercent?: number | null },
): DiscountCheck {
  if (totals.quoteDiscount > round2(totals.subtotal - totals.itemsDiscount)) {
    return { ok: false, message: 'O desconto não pode ser maior que o valor do orçamento.' }
  }
  if (totals.discountPercent <= opts.maxPercent || opts.canExceed) return { ok: true }
  if (opts.authorizedPercent != null && totals.discountPercent <= opts.authorizedPercent + 0.0001) return { ok: true }
  return {
    ok: false,
    message: `Desconto acima do seu limite de ${opts.maxPercent.toLocaleString('pt-BR')}%. Solicite a autorização de um gerente.`,
  }
}
