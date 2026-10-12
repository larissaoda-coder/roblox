import { cn } from '@/lib/cn'

/** Marca: três faixas em tons de cinza, representando níveis de transmissão luminosa. */
export function LogoMark({ className, inverted = false }: { className?: string; inverted?: boolean }) {
  return (
    <svg viewBox="0 0 32 32" className={cn('h-7 w-7', className)} aria-hidden="true">
      <rect width="32" height="32" rx="7" fill={inverted ? '#ffffff' : '#0a0a0a'} />
      <rect x="8" y="8" width="4" height="16" rx="1" fill={inverted ? '#0a0a0a' : '#ffffff'} />
      <rect x="14" y="8" width="4" height="16" rx="1" fill="#a3a3a3" />
      <rect x="20" y="8" width="4" height="16" rx="1" fill={inverted ? '#d4d4d4' : '#525252'} />
    </svg>
  )
}

export function Logo({ className, inverted = false, compact = false }: { className?: string; inverted?: boolean; compact?: boolean }) {
  return (
    <span className={cn('inline-flex items-center gap-2.5', className)}>
      <LogoMark inverted={inverted} />
      {!compact && (
        <span className={cn('text-[13px] font-semibold tracking-[0.22em]', inverted ? 'text-white' : 'text-neutral-950')}>
          ART PELÍCULAS
        </span>
      )}
    </span>
  )
}
