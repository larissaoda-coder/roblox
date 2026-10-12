import { Suspense, useEffect, useState } from 'react'
import { Link, Outlet, useLocation } from 'react-router-dom'
import { Menu, Plus, X } from 'lucide-react'
import { PageLoader } from '@/components/ui'
import { useAuth } from '@/auth/AuthProvider'
import { Logo } from './Logo'
import { NAV_ITEMS } from './navigation'
import { SidebarContent } from './Sidebar'
import { UserMenu } from './UserMenu'

function useSectionTitle() {
  const { pathname } = useLocation()
  const match = [...NAV_ITEMS].sort((a, b) => b.to.length - a.to.length).find((i) => (i.end ? pathname === i.to : pathname.startsWith(i.to)))
  return match?.label ?? ''
}

/** Estrutura padrão das páginas internas: menu lateral, cabeçalho e área de conteúdo. */
export function AppLayout() {
  const [mobileOpen, setMobileOpen] = useState(false)
  const location = useLocation()
  const section = useSectionTitle()
  const { can } = useAuth()

  useEffect(() => setMobileOpen(false), [location.pathname])
  useEffect(() => {
    document.title = section ? `${section} · Art Películas` : 'Art Películas'
  }, [section])

  return (
    <div className="min-h-screen bg-white">
      <a href="#conteudo" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[70] focus:rounded-md focus:bg-neutral-950 focus:px-4 focus:py-2 focus:text-white">
        Pular para o conteúdo
      </a>

      {/* Menu lateral (desktop) */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 border-r border-neutral-200 bg-neutral-50 lg:block">
        <SidebarContent />
      </aside>

      {/* Menu lateral (celular/tablet) */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true" aria-label="Menu">
          <div className="absolute inset-0 animate-overlay-in bg-neutral-950/40" onClick={() => setMobileOpen(false)} />
          <div className="absolute inset-y-0 left-0 w-72 max-w-[85vw] animate-slide-in-left border-r border-neutral-200 bg-neutral-50 shadow-lift">
            <button
              type="button"
              onClick={() => setMobileOpen(false)}
              className="absolute right-3 top-4 rounded-md p-2 text-neutral-500 hover:bg-neutral-200/60 hover:text-neutral-950"
              aria-label="Fechar menu"
            >
              <X className="h-5 w-5" />
            </button>
            <SidebarContent onNavigate={() => setMobileOpen(false)} />
          </div>
        </div>
      )}

      <div className="lg:pl-64">
        <header className="no-print sticky top-0 z-20 flex h-16 items-center gap-3 border-b border-neutral-200 bg-white/90 px-4 backdrop-blur sm:px-6 lg:px-8">
          <button
            type="button"
            onClick={() => setMobileOpen(true)}
            className="-ml-1.5 rounded-md p-2 text-neutral-700 hover:bg-neutral-100 lg:hidden"
            aria-label="Abrir menu"
          >
            <Menu className="h-5 w-5" />
          </button>
          <Link to="/app" className="lg:hidden" aria-label="Início">
            <Logo compact />
          </Link>
          <p className="hidden truncate text-sm font-medium text-neutral-500 sm:block">{section}</p>
          <div className="ml-auto flex items-center gap-2">
            {can('orcamentos.gerenciar') && (
              <Link
                to="/app/orcamentos/novo"
                className="hidden h-9 items-center gap-1.5 rounded-md border border-neutral-300 px-3 text-[13px] font-medium text-neutral-900 transition-colors hover:bg-neutral-50 md:inline-flex"
              >
                <Plus className="h-4 w-4" /> Novo orçamento
              </Link>
            )}
            <UserMenu />
          </div>
        </header>
        <main id="conteudo" className="mx-auto w-full max-w-7xl px-4 py-6 sm:px-6 sm:py-8 lg:px-8">
          <Suspense fallback={<PageLoader />}>
            <div key={location.pathname} className="animate-fade-in">
              <Outlet />
            </div>
          </Suspense>
        </main>
      </div>
    </div>
  )
}
