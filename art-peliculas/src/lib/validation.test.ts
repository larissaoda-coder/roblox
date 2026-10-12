import { describe, expect, it } from 'vitest'
import { isValidCpfCnpj, isValidPlate, passwordSchema } from './validation'

describe('CPF/CNPJ', () => {
  it('aceita CPFs válidos com ou sem máscara', () => {
    expect(isValidCpfCnpj('529.982.247-25')).toBe(true)
    expect(isValidCpfCnpj('52998224725')).toBe(true)
  })
  it('rejeita CPFs inválidos e sequências repetidas', () => {
    expect(isValidCpfCnpj('529.982.247-24')).toBe(false)
    expect(isValidCpfCnpj('111.111.111-11')).toBe(false)
    expect(isValidCpfCnpj('123')).toBe(false)
  })
  it('aceita CNPJ numérico e alfanumérico', () => {
    expect(isValidCpfCnpj('11.222.333/0001-81')).toBe(true)
    // Exemplo oficial do CNPJ alfanumérico (Receita Federal)
    expect(isValidCpfCnpj('12.ABC.345/01DE-35')).toBe(true)
  })
  it('rejeita CNPJ com dígito verificador errado', () => {
    expect(isValidCpfCnpj('11.222.333/0001-82')).toBe(false)
    expect(isValidCpfCnpj('12.ABC.345/01DE-36')).toBe(false)
  })
})

describe('placas', () => {
  it('aceita padrão antigo e Mercosul', () => {
    expect(isValidPlate('ABC-1234')).toBe(true)
    expect(isValidPlate('abc1d23')).toBe(true)
  })
  it('rejeita formatos inválidos', () => {
    expect(isValidPlate('AB-12345')).toBe(false)
    expect(isValidPlate('1234ABC')).toBe(false)
  })
})

describe('senha', () => {
  it('exige 8+ caracteres com letras e números', () => {
    expect(passwordSchema.safeParse('abc12345').success).toBe(true)
    expect(passwordSchema.safeParse('abcdefgh').success).toBe(false)
    expect(passwordSchema.safeParse('12345678').success).toBe(false)
    expect(passwordSchema.safeParse('ab1').success).toBe(false)
  })
})
