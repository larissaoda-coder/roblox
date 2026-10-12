import { Link, Outlet } from 'react-router-dom'
import { useAuth } from '@/auth/AuthProvider'
import { Logo } from './Logo'

export function PublicHeader() {
  const { session } = useAuth()
  return (
    <header className="sticky top-0 z-30 border-b border-neutral-200/80 bg-white/85 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Link to="/" aria-label="Art Películas — início">
          <Logo />
        </Link>
        <nav className="flex items-center gap-1 sm:gap-2" aria-label="Navegação principal">
          <a href="/#recursos" className="hidden rounded-md px-3 py-2 text-sm font-medium text-neutral-600 transition-colors hover:text-neutral-950 sm:block">
            Recursos
          </a>
          <a href="/#como-funciona" className="hidden rounded-md px-3 py-2 text-sm font-medium text-neutral-600 transition-colors hover:text-neutral-950 md:block">
            Como funciona
          </a>
          <Link
            to={session ? '/app' : '/entrar'}
            className="inline-flex h-9 items-center rounded-md bg-neutral-950 px-4 text-sm font-medium text-white shadow-soft transition-colors hover:bg-neutral-800"
          >
            {session ? 'Acessar painel' : 'Entrar'}
          </Link>
        </nav>
      </div>
    </header>
  )
}

export function PublicFooter() {
  return (
    <footer className="border-t border-neutral-200 bg-neutral-50">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-10 sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <Logo />
        <p className="text-xs text-neutral-500">© {new Date().getFullYear()} Art Películas. Sistema interno de simulação, orçamentos e gestão.</p>
      </div>
    </footer>
  )
}

export function PublicLayout() {
  return (
    <div className="flex min-h-screen flex-col bg-white">
      <PublicHeader />
      <main className="flex-1">
        <Outlet />
      </main>
      <PublicFooter />
    </div>
  )
}
