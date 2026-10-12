import { NavLink } from 'react-router-dom'
import { useAuth } from '@/auth/AuthProvider'
import { cn } from '@/lib/cn'
import { Logo } from './Logo'
import { NAV_ITEMS } from './navigation'

export function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
  const { can } = useAuth()
  const items = NAV_ITEMS.filter((item) => !item.permission || can(item.permission))

  return (
    <div className="flex h-full flex-col">
      <div className="flex h-16 shrink-0 items-center px-5">
        <NavLink to="/app" onClick={onNavigate} aria-label="Art Películas — Visão geral">
          <Logo />
        </NavLink>
      </div>
      <nav className="scrollbar-thin flex-1 overflow-y-auto px-3 pb-4" aria-label="Menu principal">
        <ul className="space-y-0.5">
          {items.map((item) => (
            <li key={item.to}>
              {item.dividerBefore && <div className="mx-2 my-3 border-t border-neutral-200" role="separator" />}
              <NavLink
                to={item.to}
                end={item.end}
                onClick={onNavigate}
                className={({ isActive }) =>
                  cn(
                    'group flex items-center gap-3 rounded-md px-3 py-2 text-[13.5px] font-medium transition-colors duration-150',
                    isActive ? 'bg-neutral-950 text-white' : 'text-neutral-600 hover:bg-neutral-200/60 hover:text-neutral-950',
                  )
                }
              >
                <item.icon className="h-[18px] w-[18px] shrink-0" strokeWidth={1.6} />
                <span className="truncate">{item.label}</span>
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>
      <div className="border-t border-neutral-200 px-5 py-4 text-[11px] leading-relaxed text-neutral-400">
        © {new Date().getFullYear()} Art Películas
        <br />
        Sistema de gestão e simulação
      </div>
    </div>
  )
}
