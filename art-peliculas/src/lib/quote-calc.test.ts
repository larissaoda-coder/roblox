import { describe, expect, it } from 'vitest'
import { checkDiscount, computeQuoteTotals } from './quote-calc'

const items = [
  { quantity: 1, unit_price: 450, discount: 0 },
  { quantity: 2, unit_price: 80.5, discount: 10 },
]

describe('cálculo do orçamento', () => {
  it('soma itens, descontos e total', () => {
    const t = computeQuoteTotals(items, 'valor', 20)
    expect(t.subtotal).toBe(611)
    expect(t.itemsDiscount).toBe(10)
    expect(t.quoteDiscount).toBe(20)
    expect(t.discountTotal).toBe(30)
    expect(t.total).toBe(581)
  })
  it('aplica desconto percentual sobre o valor líquido dos itens', () => {
    const t = computeQuoteTotals(items, 'percentual', 10)
    expect(t.quoteDiscount).toBe(60.1)
    expect(t.total).toBe(540.9)
    expect(t.discountPercent).toBeCloseTo(11.473, 3)
  })
  it('evita erros de ponto flutuante', () => {
    const t = computeQuoteTotals([{ quantity: 3, unit_price: 0.1, discount: 0 }], 'valor', 0)
    expect(t.subtotal).toBe(0.3)
  })
})

describe('limite de desconto', () => {
  const t = computeQuoteTotals([{ quantity: 1, unit_price: 1000, discount: 0 }], 'percentual', 15)
  it('bloqueia acima do limite sem permissão', () => {
    expect(checkDiscount(t, { maxPercent: 10, canExceed: false }).ok).toBe(false)
  })
  it('permite com permissão de autorizar', () => {
    expect(checkDiscount(t, { maxPercent: 10, canExceed: true }).ok).toBe(true)
  })
  it('mantém desconto já autorizado por um gerente', () => {
    expect(checkDiscount(t, { maxPercent: 10, canExceed: false, authorizedPercent: 15 }).ok).toBe(true)
    expect(checkDiscount(t, { maxPercent: 10, canExceed: false, authorizedPercent: 12 }).ok).toBe(false)
  })
  it('rejeita desconto maior que o valor', () => {
    const big = computeQuoteTotals([{ quantity: 1, unit_price: 100, discount: 0 }], 'valor', 150)
    expect(checkDiscount(big, { maxPercent: 100, canExceed: true }).ok).toBe(false)
  })
})
