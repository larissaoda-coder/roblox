import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { FunctionsHttpError } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import { AppError, ensureAffected } from '@/lib/errors'
import type { AppRole, ManagedUser, Permission, PermissionDef, RolePermission } from '@/types/domain'

export function useUsers() {
  return useQuery({
    queryKey: ['users'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('list_users')
      if (error) throw error
      return data as ManagedUser[]
    },
  })
}

export function usePermissionMatrix() {
  return useQuery({
    queryKey: ['permissions'],
    queryFn: async () => {
      const [perms, matrix] = await Promise.all([
        supabase.from('permissions').select('*').order('sort_order'),
        supabase.from('role_permissions').select('*'),
      ])
      if (perms.error) throw perms.error
      if (matrix.error) throw matrix.error
      return { permissions: perms.data as PermissionDef[], matrix: matrix.data as RolePermission[] }
    },
  })
}

/** Chama a Edge Function de administração e converte o erro retornado em mensagem amigável. */
async function invokeAdmin<T>(body: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke('admin-users', { body })
  if (error) {
    if (error instanceof FunctionsHttpError) {
      const payload = await error.context.json().catch(() => null)
      throw new AppError(payload?.error ?? 'Não foi possível concluir a operação.')
    }
    throw new AppError('Não foi possível contatar o servidor de administração. Verifique se a função "admin-users" foi publicada.')
  }
  return data as T
}

export interface NewUserInput {
  mode: 'invite' | 'create'
  email: string
  full_name: string
  role: AppRole
  password?: string
}

export function useCreateUser() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: NewUserInput) =>
      invokeAdmin<{ id: string; message: string }>({
        action: input.mode,
        email: input.email,
        full_name: input.full_name,
        role: input.role,
        password: input.password,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['users'] })
      void qc.invalidateQueries({ queryKey: ['team'] })
    },
  })
}

export function useSetUserActive() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) => invokeAdmin<{ message: string }>({ action: 'set_active', user_id: id, active }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['users'] })
      void qc.invalidateQueries({ queryKey: ['team'] })
    },
  })
}

export function useUpdateUserRole() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, role }: { id: string; role: AppRole }) => {
      const { data, error } = await supabase.from('profiles').update({ role }).eq('id', id).select('id')
      if (error) throw error
      ensureAffected(data)
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['users'] })
      void qc.invalidateQueries({ queryKey: ['team'] })
    },
  })
}

export function useSendReset() {
  return useMutation({
    mutationFn: async (email: string) => {
      const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/redefinir-senha` })
      if (error) throw error
    },
  })
}

export function useTogglePermission() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ role, permission, enabled }: { role: AppRole; permission: Permission; enabled: boolean }) => {
      if (enabled) {
        const { error } = await supabase.from('role_permissions').insert({ role, permission })
        if (error) throw error
      } else {
        const { data, error } = await supabase.from('role_permissions').delete().eq('role', role).eq('permission', permission).select('role')
        if (error) throw error
        ensureAffected(data)
      }
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['permissions'] })
      void qc.invalidateQueries({ queryKey: ['me'] })
    },
  })
}
