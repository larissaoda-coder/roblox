import { z } from 'zod'
import { normalizeDocument, normalizePlate, onlyDigits, parseDecimal } from './format'

/** Valida CPF (11 dígitos) ou CNPJ (14 caracteres, numérico ou alfanumérico). Mesmo algoritmo do banco. */
export function isValidCpfCnpj(value: string | null | undefined): boolean {
  const d = normalizeDocument(value)
  if (d.length === 11) {
    if (!/^\d{11}$/.test(d) || /^(.)\1{10}$/.test(d)) return false
    const calc = (len: number) => {
      let s = 0
      for (let i = 0; i < len; i++) s += Number(d[i]) * (len + 1 - i)
      const r = (s * 10) % 11
      return r === 10 ? 0 : r
    }
    return calc(9) === Number(d[9]) && calc(10) === Number(d[10])
  }
  if (d.length === 14) {
    if (!/^[0-9A-Z]{12}\d{2}$/.test(d) || /^(.)\1{13}$/.test(d)) return false
    const value = (c: string) => c.charCodeAt(0) - 48
    const calc = (weights: number[]) => {
      let s = 0
      weights.forEach((w, i) => (s += value(d[i]) * w))
      const r = s % 11
      return r < 2 ? 0 : 11 - r
    }
    return (
      calc([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) === Number(d[12]) &&
      calc([6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) === Number(d[13])
    )
  }
  return false
}

export function isValidPlate(value: string | null | undefined) {
  return /^[A-Z]{3}\d[A-Z0-9]\d{2}$/.test(normalizePlate(value))
}

export const PASSWORD_RULE = 'Use pelo menos 8 caracteres, com letras e números.'

export const passwordSchema = z
  .string()
  .min(8, PASSWORD_RULE)
  .max(72, 'A senha pode ter no máximo 72 caracteres.')
  .refine((v) => /[A-Za-z]/.test(v) && /\d/.test(v), PASSWORD_RULE)

export const emailSchema = z
  .string()
  .trim()
  .min(1, 'Informe o e-mail.')
  .max(160, 'E-mail muito longo.')
  .email('Informe um e-mail válido.')

export const optionalEmail = z
  .string()
  .trim()
  .max(160, 'E-mail muito longo.')
  .refine((v) => v === '' || z.string().email().safeParse(v).success, 'Informe um e-mail válido.')

export const optionalPhone = z
  .string()
  .trim()
  .refine((v) => v === '' || /^\d{10,13}$/.test(onlyDigits(v)), 'Telefone inválido. Inclua o DDD.')

export const optionalDocument = z
  .string()
  .trim()
  .refine((v) => v === '' || isValidCpfCnpj(v), 'CPF ou CNPJ inválido.')

export const optionalPlate = z
  .string()
  .trim()
  .refine((v) => v === '' || isValidPlate(v), 'Placa inválida (AAA-9999 ou AAA9A99).')

/** Campo numérico digitado como texto (aceita vírgula). */
export function decimalField(opts: { min?: number; max?: number; required?: boolean; label?: string } = {}) {
  const { min, max, required = true, label = 'o valor' } = opts
  return z
    .string()
    .trim()
    .refine((v) => !required || v !== '', `Informe ${label}.`)
    .refine((v) => v === '' || Number.isFinite(parseDecimal(v)), 'Número inválido.')
    .refine((v) => v === '' || min === undefined || parseDecimal(v) >= min, `O valor mínimo é ${min}.`)
    .refine((v) => v === '' || max === undefined || parseDecimal(v) <= max, `O valor máximo é ${max}.`)
}

export function intField(opts: { min?: number; max?: number; required?: boolean; label?: string } = {}) {
  return decimalField(opts).refine((v) => v === '' || Number.isInteger(parseDecimal(v)), 'Use um número inteiro.')
}

export function toNullableNumber(v: string) {
  return v.trim() === '' ? null : parseDecimal(v)
}
