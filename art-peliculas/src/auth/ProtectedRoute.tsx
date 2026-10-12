import type { ReactNode } from 'react'
import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { Lock, UserX } from 'lucide-react'
import { Button, EmptyState, PageLoader } from '@/components/ui'
import { toMessage } from '@/lib/errors'
import type { Permission } from '@/types/domain'
import { useAuth } from './AuthProvider'
import { Logo } from '@/components/layout/Logo'

/** Bloqueia o acesso de visitantes não autenticados ou com conta desativada. */
export function ProtectedRoute() {
  const { session, initializing, profile, profileLoading, profileError, signOut, refreshProfile } = useAuth()
  const location = useLocation()

  if (initializing || profileLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <PageLoader label="Verificando acesso…" />
      </div>
    )
  }

  if (!session) {
    return <Navigate to="/entrar" replace state={{ from: `${location.pathname}${location.search}` }} />
  }

  if (profileError) {
    return (
      <CenteredMessage>
        <EmptyState
          icon={Lock}
          title="Não foi possível carregar o seu perfil"
          description={toMessage(profileError)}
          action={
            <div className="flex gap-2">
              <Button variant="secondary" onClick={() => void refreshProfile()}>
                Tentar novamente
              </Button>
              <Button onClick={() => void signOut()}>Sair</Button>
            </div>
          }
        />
      </CenteredMessage>
    )
  }

  if (!profile || !profile.active) {
    return (
      <CenteredMessage>
        <EmptyState
          icon={UserX}
          title="Acesso ainda não liberado"
          description="Sua conta existe, mas está desativada ou aguardando liberação de um administrador da Art Películas."
          action={<Button onClick={() => void signOut()}>Sair</Button>}
        />
      </CenteredMessage>
    )
  }

  return <Outlet />
}

function CenteredMessage({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-neutral-50 px-4">
      <div className="mb-8">
        <Logo />
      </div>
      <div className="w-full max-w-md rounded-2xl border border-neutral-200 bg-white shadow-soft">{children}</div>
    </div>
  )
}

/** Exibe o conteúdo somente para quem tem a permissão informada. */
export function RequirePermission({ permission, children }: { permission: Permission; children: ReactNode }) {
  const { can } = useAuth()
  if (!can(permission)) {
    return (
      <EmptyState
        icon={Lock}
        title="Acesso restrito"
        description="Seu papel de acesso não permite visualizar esta área. Fale com um administrador se precisar desta permissão."
        className="py-24"
      />
    )
  }
  return <>{children}</>
}

/** Renderiza os filhos somente quando o usuário tem a permissão. */
export function Can({ permission, children, fallback = null }: { permission: Permission; children: ReactNode; fallback?: ReactNode }) {
  const { can } = useAuth()
  return <>{can(permission) ? children : fallback}</>
}
