import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { ChevronDown, LogOut, UserRound } from 'lucide-react'
import { useAuth } from '@/auth/AuthProvider'
import { ROLE_LABELS } from '@/lib/constants'
import { initials } from '@/lib/format'
import { cn } from '@/lib/cn'

export function UserMenu() {
  const { profile, signOut } = useAuth()
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const onDoc = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false)
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false)
    document.addEventListener('mousedown', onDoc)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onDoc)
      document.removeEventListener('keydown', onKey)
    }
  }, [open])

  if (!profile) return null

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-haspopup="menu"
        className="flex items-center gap-2.5 rounded-full py-1 pl-1 pr-2 transition-colors hover:bg-neutral-100"
      >
        <span className="flex h-8 w-8 items-center justify-center rounded-full bg-neutral-950 text-[12px] font-semibold text-white">
          {initials(profile.full_name || profile.email)}
        </span>
        <span className="hidden text-left leading-tight sm:block">
          <span className="block max-w-[160px] truncate text-[13px] font-medium text-neutral-900">{profile.full_name || profile.email}</span>
          <span className="block text-[11px] text-neutral-500">{ROLE_LABELS[profile.role]}</span>
        </span>
        <ChevronDown className={cn('hidden h-4 w-4 text-neutral-400 transition-transform sm:block', open && 'rotate-180')} />
      </button>
      {open && (
        <div role="menu" className="absolute right-0 z-40 mt-2 w-60 animate-fade-in rounded-xl border border-neutral-200 bg-white p-1.5 shadow-lift">
          <div className="border-b border-neutral-100 px-3 py-2.5">
            <p className="truncate text-sm font-medium text-neutral-950">{profile.full_name}</p>
            <p className="truncate text-xs text-neutral-500">{profile.email}</p>
          </div>
          <Link
            role="menuitem"
            to="/app/configuracoes"
            onClick={() => setOpen(false)}
            className="mt-1 flex items-center gap-2.5 rounded-md px-3 py-2 text-sm text-neutral-700 hover:bg-neutral-100 hover:text-neutral-950"
          >
            <UserRound className="h-4 w-4" strokeWidth={1.75} /> Meu perfil e senha
          </Link>
          <button
            role="menuitem"
            type="button"
            onClick={() => void signOut()}
            className="flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-sm text-neutral-700 hover:bg-neutral-100 hover:text-neutral-950"
          >
            <LogOut className="h-4 w-4" strokeWidth={1.75} /> Sair
          </button>
        </div>
      )}
    </div>
  )
}
