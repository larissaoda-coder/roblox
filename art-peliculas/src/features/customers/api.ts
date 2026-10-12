import { useMutation, useQuery, useQueryClient, keepPreviousData } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ensureAffected } from '@/lib/errors'
import { normalizeDocument, onlyDigits } from '@/lib/format'
import type { Customer } from '@/types/domain'

export const customerKeys = {
  all: ['customers'] as const,
  list: (search: string, page: number) => ['customers', 'list', search, page] as const,
  detail: (id: string) => ['customers', 'detail', id] as const,
  options: (search: string) => ['customers', 'options', search] as const,
}

export const PAGE_SIZE = 20

/** Monta o filtro de busca por nome, documento, telefone, e-mail ou cidade. */
function searchFilter(term: string) {
  const t = term.trim().replace(/[,()*%]/g, ' ').trim()
  if (!t) return null
  const parts = [`name.ilike.*${t}*`, `email.ilike.*${t}*`, `city.ilike.*${t}*`]
  const doc = normalizeDocument(t)
  if (doc.length >= 3 && /\d/.test(doc)) parts.push(`document.ilike.*${doc}*`)
  const phone = onlyDigits(t)
  if (phone.length >= 4) parts.push(`phone.ilike.*${phone}*`)
  return parts.join(',')
}

export function useCustomers(search: string, page: number) {
  return useQuery({
    queryKey: customerKeys.list(search, page),
    placeholderData: keepPreviousData,
    queryFn: async () => {
      let q = supabase
        .from('customers')
        .select('*', { count: 'exact' })
        .order('name')
        .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1)
      const f = searchFilter(search)
      if (f) q = q.or(f)
      const { data, error, count } = await q
      if (error) throw error
      return { rows: data as Customer[], total: count ?? 0 }
    },
  })
}

export function useCustomer(id: string | undefined) {
  return useQuery({
    queryKey: customerKeys.detail(id ?? ''),
    enabled: Boolean(id),
    queryFn: async () => {
      const { data, error } = await supabase.from('customers').select('*').eq('id', id!).maybeSingle()
      if (error) throw error
      return data as Customer | null
    },
  })
}

/** Opções para seletores com busca no servidor. */
export function useCustomerOptions(search: string) {
  return useQuery({
    queryKey: customerKeys.options(search),
    placeholderData: keepPreviousData,
    queryFn: async () => {
      let q = supabase.from('customers').select('id, name, document, phone, city').order('name').limit(30)
      const f = searchFilter(search)
      if (f) q = q.or(f)
      const { data, error } = await q
      if (error) throw error
      return data as Array<Pick<Customer, 'id' | 'name' | 'document' | 'phone' | 'city'>>
    },
  })
}

export type CustomerInput = Omit<Customer, 'id' | 'created_by' | 'created_at' | 'updated_at'>

export function useSaveCustomer() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, input }: { id?: string; input: CustomerInput }) => {
      if (id) {
        const { data, error } = await supabase.from('customers').update(input).eq('id', id).select()
        if (error) throw error
        return ensureAffected(data)[0] as Customer
      }
      const { data, error } = await supabase.from('customers').insert(input).select().single()
      if (error) throw error
      return data as Customer
    },
    onSuccess: (c) => {
      void qc.invalidateQueries({ queryKey: customerKeys.all })
      void qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.setQueryData(customerKeys.detail(c.id), c)
    },
  })
}

export function useDeleteCustomer() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (id: string) => {
      const { data, error } = await supabase.from('customers').delete().eq('id', id).select('id')
      if (error) throw error
      ensureAffected(data)
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: customerKeys.all })
      void qc.invalidateQueries({ queryKey: ['dashboard'] })
    },
  })
}
