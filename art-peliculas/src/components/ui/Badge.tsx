import type { ReactNode } from 'react'
import { cn } from '@/lib/cn'

export type BadgeTone = 'solid' | 'outline' | 'muted' | 'subtle' | 'dashed'

const tones: Record<BadgeTone, string> = {
  solid: 'bg-neutral-950 text-white border border-neutral-950',
  outline: 'border border-neutral-900 text-neutral-900 bg-white',
  muted: 'border border-neutral-200 bg-neutral-100 text-neutral-700',
  subtle: 'border border-neutral-200 bg-white text-neutral-600',
  dashed: 'border border-dashed border-neutral-400 bg-white text-neutral-600',
}

export function Badge({ tone = 'muted', className, children, icon }: { tone?: BadgeTone; className?: string; children: ReactNode; icon?: ReactNode }) {
  return (
    <span
      className={cn(
        'inline-flex h-6 items-center gap-1 whitespace-nowrap rounded-full px-2.5 text-[11.5px] font-medium leading-none',
        tones[tone],
        className,
      )}
    >
      {icon}
      {children}
    </span>
  )
}
