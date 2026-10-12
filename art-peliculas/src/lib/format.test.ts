import { describe, expect, it } from 'vitest'
import { formatCurrency, formatDocument, formatPhone, formatPlate, parseDecimal, quoteCode, vehicleYears } from './format'

describe('formatação', () => {
  it('moeda em reais', () => {
    expect(formatCurrency(1234.5).replace(/\s/g, ' ')).toBe('R$ 1.234,50')
  })
  it('documentos, telefones e placas', () => {
    expect(formatDocument('52998224725')).toBe('529.982.247-25')
    expect(formatDocument('11222333000181')).toBe('11.222.333/0001-81')
    expect(formatDocument('12ABC34501DE35')).toBe('12.ABC.345/01DE-35')
    expect(formatPhone('11987654321')).toBe('(11) 98765-4321')
    expect(formatPlate('abc1234')).toBe('ABC-1234')
    expect(formatPlate('abc1d23')).toBe('ABC1D23')
  })
  it('converte números digitados em pt-BR', () => {
    expect(parseDecimal('1.234,56')).toBe(1234.56)
    expect(parseDecimal('35')).toBe(35)
    expect(parseDecimal('12.5')).toBe(12.5)
    expect(Number.isNaN(parseDecimal(''))).toBe(true)
  })
  it('códigos e anos', () => {
    expect(quoteCode(12)).toBe('ORC-00012')
    expect(vehicleYears({ year_start: 2018, year_end: null })).toBe('2018–atual')
    expect(vehicleYears({ year_start: 2013, year_end: 2016 })).toBe('2013–2016')
  })
})
