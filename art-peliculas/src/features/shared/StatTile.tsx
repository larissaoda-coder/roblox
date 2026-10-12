import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import type { LucideIcon } from 'lucide-react'
import { Skeleton } from '@/components/ui'
import { cn } from '@/lib/cn'

/** Indicador do painel: rótulo, valor em destaque e contexto secundário. */
export function StatTile({
  label,
  value,
  context,
  icon: Icon,
  to,
  loading,
}: {
  label: string
  value: ReactNode
  context?: ReactNode
  icon?: LucideIcon
  to?: string
  loading?: boolean
}) {
  const body = (
    <>
      <div className="flex items-center justify-between gap-3">
        <p className="text-[13px] font-medium text-neutral-500">{label}</p>
        {Icon && <Icon className="h-4 w-4 text-neutral-400 transition-colors group-hover:text-neutral-900" strokeWidth={1.6} />}
      </div>
      {loading ? (
        <Skeleton className="mt-3 h-8 w-24" />
      ) : (
        <p className="mt-2 text-[30px] font-semibold leading-none tracking-tight text-neutral-950">{value}</p>
      )}
      {context && <p className="mt-2.5 text-xs text-neutral-500">{loading ? <span className="invisible">.</span> : context}</p>}
    </>
  )
  const className = cn('group block rounded-xl border border-neutral-200 bg-white p-5 shadow-soft transition-all duration-150', to && 'hover:border-neutral-300 hover:shadow-lift')
  return to ? (
    <Link to={to} className={className}>
      {body}
    </Link>
  ) : (
    <div className={className}>{body}</div>
  )
}
