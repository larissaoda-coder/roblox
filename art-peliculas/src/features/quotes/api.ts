import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ensureAffected } from '@/lib/errors'
import { normalizePlate } from '@/lib/format'
import type { Customer, DiscountType, GlassZone, Quote, QuoteEvent, QuoteItem, QuoteItemKind, QuoteStatus, ServiceOrder, Simulation } from '@/types/domain'

export const QUOTES_PAGE = 20

export interface QuoteRow extends Quote {
  customer: { id: string; name: string } | null
}

export type QuoteStatusFilter = QuoteStatus | 'pendentes' | ''

export function useQuotes(filters: { status: QuoteStatusFilter; search: string; page: number }) {
  return useQuery({
    queryKey: ['quotes', 'list', filters],
    placeholderData: keepPreviousData,
    queryFn: async () => {
      const term = filters.search.trim().replace(/[,()*%]/g, ' ').trim()
      const n = Number(term.replace(/^orc-?/i, ''))
      const byNumber = term !== '' && Number.isInteger(n) && n > 0
      const plate = normalizePlate(term)
      const byPlate = !byNumber && /^[A-Z]{3}\d[A-Z0-9]\d{2}$/.test(plate)
      const byName = term !== '' && !byNumber && !byPlate
      let q = supabase
        .from('quotes')
        .select(byName ? '*, customer:customers!inner(id, name)' : '*, customer:customers(id, name)', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range((filters.page - 1) * QUOTES_PAGE, filters.page * QUOTES_PAGE - 1)
      if (filters.status === 'pendentes') q = q.in('status', ['rascunho', 'enviado'])
      else if (filters.status) q = q.eq('status', filters.status)
      if (byNumber) q = q.eq('number', n)
      if (byPlate) q = q.eq('vehicle_plate', plate)
      if (byName) q = q.ilike('customer.name', `%${term}%`)
      const { data, error, count } = await q
      if (error) throw error
      return { rows: data as unknown as QuoteRow[], total: count ?? 0 }
    },
  })
}

export interface QuoteDetail extends Quote {
  customer: Customer | null
  quote_items: QuoteItem[]
  quote_events: Array<QuoteEvent & { author: { full_name: string } | null }>
  simulation: Simulation | null
  service_orders: ServiceOrder[]
  author: { full_name: string } | null
  authorizer: { full_name: string } | null
}

export function useQuote(id: string | undefined) {
  return useQuery({
    queryKey: ['quotes', 'detail', id],
    enabled: Boolean(id),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('quotes')
        .select(
          `*, customer:customers(*), quote_items(*), quote_events(*, author:profiles(full_name)), simulation:simulations(*), service_orders(*),
           author:profiles!quotes_created_by_fkey(full_name), authorizer:profiles!quotes_discount_authorized_by_fkey(full_name)`,
        )
        .eq('id', id!)
        .maybeSingle()
      if (error) throw error
      if (!data) return null
      const q = data as unknown as QuoteDetail
      q.quote_items.sort((a, b) => a.position - b.position)
      q.quote_events.sort((a, b) => a.created_at.localeCompare(b.created_at))
      return q
    },
  })
}

export interface QuoteItemPayload {
  kind: QuoteItemKind
  film_id: string | null
  service_type_id: string | null
  glass_zones: GlassZone[]
  description: string
  quantity: number
  unit_price: number
  discount: number
}

export interface QuotePayload {
  id?: string
  customer_id: string
  vehicle_id: string | null
  vehicle_description: string
  vehicle_plate: string | null
  vehicle_year: number | null
  vehicle_color: string
  simulation_id: string | null
  valid_until: string | null
  discount_type: DiscountType
  discount_value: number
  notes: string
  internal_notes: string
  items: QuoteItemPayload[]
}

function useInvalidateQuotes() {
  const qc = useQueryClient()
  return (id?: string) => {
    void qc.invalidateQueries({ queryKey: ['quotes', 'list'] })
    void qc.invalidateQueries({ queryKey: ['dashboard'] })
    void qc.invalidateQueries({ queryKey: ['customers', 'activity'] })
    if (id) void qc.invalidateQueries({ queryKey: ['quotes', 'detail', id] })
  }
}

export function useSaveQuote() {
  const invalidate = useInvalidateQuotes()
  return useMutation({
    mutationFn: async (payload: QuotePayload) => {
      const { data, error } = await supabase.rpc('save_quote', { p_quote: payload })
      if (error) throw error
      return data as string
    },
    onSuccess: (id) => invalidate(id),
  })
}

export function useSetQuoteStatus() {
  const invalidate = useInvalidateQuotes()
  return useMutation({
    mutationFn: async ({ id, status, note }: { id: string; status: QuoteStatus; note?: string }) => {
      const { error } = await supabase.rpc('set_quote_status', { p_id: id, p_status: status, p_note: note ?? null })
      if (error) throw error
      return id
    },
    onSuccess: (id) => invalidate(id),
  })
}

export function useDeleteQuote() {
  const invalidate = useInvalidateQuotes()
  return useMutation({
    mutationFn: async (id: string) => {
      const { data, error } = await supabase.from('quotes').delete().eq('id', id).select('id')
      if (error) throw error
      ensureAffected(data)
    },
    onSuccess: () => invalidate(),
  })
}
