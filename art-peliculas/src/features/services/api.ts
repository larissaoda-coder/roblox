import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ensureAffected } from '@/lib/errors'
import type { Profile, ServiceOrder, ServiceOrderStatus, ServiceType } from '@/types/domain'

export function useServiceTypes() {
  return useQuery({
    queryKey: ['service-types'],
    queryFn: async () => {
      const { data, error } = await supabase.from('service_types').select('*').order('name')
      if (error) throw error
      return data as ServiceType[]
    },
  })
}

export type ServiceTypeInput = Pick<ServiceType, 'name' | 'description' | 'base_price' | 'estimated_minutes' | 'active'>

export function useSaveServiceType() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, input }: { id?: string; input: ServiceTypeInput }) => {
      if (id) {
        const { data, error } = await supabase.from('service_types').update(input).eq('id', id).select()
        if (error) throw error
        return ensureAffected(data)[0] as ServiceType
      }
      const { data, error } = await supabase.from('service_types').insert(input).select().single()
      if (error) throw error
      return data as ServiceType
    },
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['service-types'] }),
  })
}

export function useDeleteServiceType() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (id: string) => {
      const { data, error } = await supabase.from('service_types').delete().eq('id', id).select('id')
      if (error) throw error
      ensureAffected(data)
    },
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['service-types'] }),
  })
}

export interface ServiceOrderRow extends ServiceOrder {
  customer: { id: string; name: string } | null
  assignee: { id: string; full_name: string } | null
  quote: { id: string; number: number } | null
  service_type: { id: string; name: string } | null
}

const ORDER_SELECT =
  '*, customer:customers(id, name), assignee:profiles!service_orders_assigned_to_fkey(id, full_name), quote:quotes(id, number), service_type:service_types(id, name)'

export const ORDERS_PAGE = 20

export function useServiceOrders(filters: { status: ServiceOrderStatus | 'abertas' | ''; search: string; page: number }) {
  return useQuery({
    queryKey: ['service-orders', 'list', filters],
    placeholderData: keepPreviousData,
    queryFn: async () => {
      let q = supabase
        .from('service_orders')
        .select(ORDER_SELECT, { count: 'exact' })
        .order('scheduled_at', { ascending: filters.status === 'abertas', nullsFirst: false })
        .order('created_at', { ascending: false })
        .range((filters.page - 1) * ORDERS_PAGE, filters.page * ORDERS_PAGE - 1)
      if (filters.status === 'abertas') q = q.in('status', ['agendado', 'em_andamento'])
      else if (filters.status) q = q.eq('status', filters.status)
      const term = filters.search.trim().replace(/[,()*%]/g, ' ').trim()
      if (term) {
        const n = Number(term.replace(/^os-?/i, ''))
        if (Number.isInteger(n) && n > 0) q = q.eq('number', n)
        else q = q.or(`description.ilike.*${term}*,vehicle_description.ilike.*${term}*,vehicle_plate.ilike.*${term.toUpperCase().replace(/[^0-9A-Z]/g, '')}*`)
      }
      const { data, error, count } = await q
      if (error) throw error
      return { rows: data as unknown as ServiceOrderRow[], total: count ?? 0 }
    },
  })
}

export type ServiceOrderInput = Pick<
  ServiceOrder,
  'quote_id' | 'customer_id' | 'vehicle_id' | 'vehicle_description' | 'vehicle_plate' | 'service_type_id' | 'description' | 'status' | 'scheduled_at' | 'assigned_to' | 'price' | 'notes'
>

export function useSaveServiceOrder() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, input }: { id?: string; input: Partial<ServiceOrderInput> }) => {
      if (id) {
        const { data, error } = await supabase.from('service_orders').update(input).eq('id', id).select()
        if (error) throw error
        return ensureAffected(data)[0] as ServiceOrder
      }
      const { data, error } = await supabase.from('service_orders').insert(input).select().single()
      if (error) throw error
      return data as ServiceOrder
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['service-orders'] })
      void qc.invalidateQueries({ queryKey: ['dashboard'] })
      void qc.invalidateQueries({ queryKey: ['quotes'] })
      void qc.invalidateQueries({ queryKey: ['customers', 'activity'] })
    },
  })
}

export function useDeleteServiceOrder() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (id: string) => {
      const { data, error } = await supabase.from('service_orders').delete().eq('id', id).select('id')
      if (error) throw error
      ensureAffected(data)
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['service-orders'] })
      void qc.invalidateQueries({ queryKey: ['dashboard'] })
    },
  })
}

/** Usuários ativos (para responsável pelo serviço e nomes no histórico). */
export function useTeam() {
  return useQuery({
    queryKey: ['team'],
    staleTime: 5 * 60_000,
    queryFn: async () => {
      const { data, error } = await supabase.from('profiles').select('id, full_name, email, role, active').order('full_name')
      if (error) throw error
      return data as Array<Pick<Profile, 'id' | 'full_name' | 'email' | 'role' | 'active'>>
    },
  })
}
