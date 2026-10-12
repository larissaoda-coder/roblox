import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { Permission, Profile } from '@/types/domain'

interface Me {
  profile: Profile | null
  permissions: Permission[]
}

interface AuthContextValue {
  session: Session | null
  initializing: boolean
  profile: Profile | null
  permissions: Permission[]
  profileLoading: boolean
  profileError: unknown
  /** true quando o usuário chegou por um link de recuperação de senha. */
  recovery: boolean
  can: (permission: Permission) => boolean
  refreshProfile: () => Promise<unknown>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export async function fetchMe(userId: string): Promise<Me> {
  const [profileRes, permsRes] = await Promise.all([
    supabase.from('profiles').select('*').eq('id', userId).maybeSingle(),
    supabase.rpc('my_permissions'),
  ])
  if (profileRes.error) throw profileRes.error
  if (permsRes.error) throw permsRes.error
  return { profile: (profileRes.data as Profile | null) ?? null, permissions: (permsRes.data as Permission[]) ?? [] }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient()
  const [session, setSession] = useState<Session | null>(null)
  const [initializing, setInitializing] = useState(true)
  const [recovery, setRecovery] = useState(false)

  useEffect(() => {
    let mounted = true
    supabase.auth.getSession().then(({ data }) => {
      if (!mounted) return
      setSession(data.session)
      setInitializing(false)
    })
    const { data: sub } = supabase.auth.onAuthStateChange((event, next) => {
      setSession(next)
      setInitializing(false)
      if (event === 'PASSWORD_RECOVERY') setRecovery(true)
      if (event === 'SIGNED_OUT') {
        setRecovery(false)
        queryClient.clear()
      }
    })
    return () => {
      mounted = false
      sub.subscription.unsubscribe()
    }
  }, [queryClient])

  const userId = session?.user.id
  const meQuery = useQuery({
    queryKey: ['me', userId],
    queryFn: () => fetchMe(userId!),
    enabled: Boolean(userId),
    staleTime: 60_000,
    retry: 1,
  })

  const permissions = useMemo(() => meQuery.data?.permissions ?? [], [meQuery.data])
  const can = useCallback((p: Permission) => permissions.includes(p), [permissions])

  const signOut = useCallback(async () => {
    await supabase.auth.signOut()
    setSession(null)
    queryClient.clear()
  }, [queryClient])

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      initializing,
      profile: meQuery.data?.profile ?? null,
      permissions,
      profileLoading: Boolean(userId) && meQuery.isLoading,
      profileError: meQuery.error,
      recovery,
      can,
      refreshProfile: () => meQuery.refetch(),
      signOut,
    }),
    [session, initializing, meQuery, permissions, recovery, can, signOut, userId],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth deve ser usado dentro de AuthProvider')
  return ctx
}

export function useCan(permission: Permission) {
  return useAuth().can(permission)
}
