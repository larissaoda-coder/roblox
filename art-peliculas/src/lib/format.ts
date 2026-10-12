const brl = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' })
const num = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 2 })
const dateFmt = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' })
const dateTimeFmt = new Intl.DateTimeFormat('pt-BR', {
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
})
const longDateFmt = new Intl.DateTimeFormat('pt-BR', { day: 'numeric', month: 'long', year: 'numeric' })

export function formatCurrency(value: number | null | undefined) {
  return brl.format(Number(value ?? 0))
}

export function formatNumber(value: number | null | undefined) {
  return num.format(Number(value ?? 0))
}

export function formatPercent(value: number | null | undefined) {
  if (value === null || value === undefined) return '—'
  return `${num.format(Number(value))}%`
}

/** Datas "YYYY-MM-DD" são tratadas como data local (sem fuso). */
function toDate(value: string | Date) {
  if (value instanceof Date) return value
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const [y, m, d] = value.split('-').map(Number)
    return new Date(y, m - 1, d)
  }
  return new Date(value)
}

export function formatDate(value: string | Date | null | undefined) {
  if (!value) return '—'
  return dateFmt.format(toDate(value))
}

export function formatLongDate(value: string | Date | null | undefined) {
  if (!value) return '—'
  return longDateFmt.format(toDate(value))
}

export function formatDateTime(value: string | Date | null | undefined) {
  if (!value) return '—'
  return dateTimeFmt.format(toDate(value))
}

export function formatRelative(value: string | Date | null | undefined, now = new Date()) {
  if (!value) return '—'
  const date = toDate(value)
  const diff = (now.getTime() - date.getTime()) / 1000
  if (diff < 60) return 'agora mesmo'
  if (diff < 3600) {
    const m = Math.floor(diff / 60)
    return `há ${m} min`
  }
  if (diff < 86400) {
    const h = Math.floor(diff / 3600)
    return `há ${h} h`
  }
  if (diff < 86400 * 7) {
    const d = Math.floor(diff / 86400)
    return d === 1 ? 'ontem' : `há ${d} dias`
  }
  return formatDate(date)
}

export function onlyDigits(value: string | null | undefined) {
  return (value ?? '').replace(/\D/g, '')
}

/** Mantém dígitos e letras maiúsculas (CNPJ alfanumérico). */
export function normalizeDocument(value: string | null | undefined) {
  return (value ?? '').toUpperCase().replace(/[^0-9A-Z]/g, '')
}

export function formatDocument(value: string | null | undefined) {
  const d = normalizeDocument(value)
  if (d.length === 11) return d.replace(/^(\d{3})(\d{3})(\d{3})(\d{2})$/, '$1.$2.$3-$4')
  if (d.length === 14) return d.replace(/^(\w{2})(\w{3})(\w{3})(\w{4})(\w{2})$/, '$1.$2.$3/$4-$5')
  return value ?? ''
}

export function formatPhone(value: string | null | undefined) {
  const d = onlyDigits(value)
  if (d.length === 11) return d.replace(/^(\d{2})(\d{5})(\d{4})$/, '($1) $2-$3')
  if (d.length === 10) return d.replace(/^(\d{2})(\d{4})(\d{4})$/, '($1) $2-$3')
  if (d.length > 11) return `+${d}`
  return value ?? ''
}

export function formatZip(value: string | null | undefined) {
  const d = onlyDigits(value)
  return d.length === 8 ? d.replace(/^(\d{5})(\d{3})$/, '$1-$2') : (value ?? '')
}

export function normalizePlate(value: string | null | undefined) {
  return (value ?? '').toUpperCase().replace(/[^0-9A-Z]/g, '')
}

export function formatPlate(value: string | null | undefined) {
  const p = normalizePlate(value)
  if (/^[A-Z]{3}\d{4}$/.test(p)) return `${p.slice(0, 3)}-${p.slice(3)}`
  return p
}

export function quoteCode(n: number | null | undefined) {
  return `ORC-${String(n ?? 0).padStart(5, '0')}`
}

export function serviceOrderCode(n: number | null | undefined) {
  return `OS-${String(n ?? 0).padStart(5, '0')}`
}

export function vehicleName(v: { brand: string; model: string; generation?: string | null } | null | undefined) {
  if (!v) return ''
  return [v.brand, v.model, v.generation].filter(Boolean).join(' ')
}

export function vehicleYears(v: { year_start: number | null; year_end: number | null }) {
  if (!v.year_start && !v.year_end) return ''
  if (v.year_start && !v.year_end) return `${v.year_start}–atual`
  if (!v.year_start) return `até ${v.year_end}`
  return v.year_start === v.year_end ? String(v.year_start) : `${v.year_start}–${v.year_end}`
}

export function initials(name: string | null | undefined) {
  const parts = (name ?? '').trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return '?'
  return ((parts[0][0] ?? '') + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase()
}

/** Converte texto digitado em número (aceita vírgula decimal). */
export function parseDecimal(value: string | number | null | undefined) {
  if (typeof value === 'number') return value
  const s = (value ?? '').toString().trim()
  if (!s) return NaN
  const normalized = s.includes(',') ? s.replace(/\./g, '').replace(',', '.') : s
  return Number(normalized)
}

export function todayISO() {
  const d = new Date()
  const off = d.getTimezoneOffset()
  return new Date(d.getTime() - off * 60000).toISOString().slice(0, 10)
}
