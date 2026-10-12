import { cn } from '@/lib/cn'

export function Tabs<T extends string>({
  value,
  onChange,
  items,
  className,
}: {
  value: T
  onChange: (value: T) => void
  items: Array<{ value: T; label: string; count?: number }>
  className?: string
}) {
  return (
    <div role="tablist" className={cn('scrollbar-thin relative flex gap-1 overflow-x-auto border-b border-neutral-200', className)}>
      {items.map((item) => {
        const active = item.value === value
        return (
          <button
            key={item.value}
            role="tab"
            type="button"
            aria-selected={active}
            onClick={() => onChange(item.value)}
            className={cn(
              'relative -mb-px flex shrink-0 items-center gap-2 whitespace-nowrap border-b-2 px-3 py-2.5 text-sm font-medium transition-colors',
              active ? 'border-neutral-950 text-neutral-950' : 'border-transparent text-neutral-500 hover:text-neutral-900',
            )}
          >
            {item.label}
            {item.count !== undefined && (
              <span className={cn('rounded-full px-1.5 py-0.5 text-[11px] leading-none', active ? 'bg-neutral-950 text-white' : 'bg-neutral-100 text-neutral-600')}>
                {item.count}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )
}

/** Grupo de botões segmentados (ex.: filtros rápidos). */
export function Segmented<T extends string | number>({
  value,
  onChange,
  items,
  className,
  size = 'md',
  ariaLabel,
}: {
  value: T
  onChange: (value: T) => void
  items: Array<{ value: T; label: string }>
  className?: string
  size?: 'sm' | 'md'
  ariaLabel?: string
}) {
  return (
    <div role="radiogroup" aria-label={ariaLabel} className={cn('inline-flex rounded-lg border border-neutral-200 bg-neutral-50 p-0.5', className)}>
      {items.map((item) => {
        const active = item.value === value
        return (
          <button
            key={String(item.value)}
            type="button"
            role="radio"
            aria-checked={active}
            onClick={() => onChange(item.value)}
            className={cn(
              'rounded-md font-medium transition-all duration-150',
              size === 'sm' ? 'px-2.5 py-1 text-xs' : 'px-3 py-1.5 text-[13px]',
              active ? 'bg-white text-neutral-950 shadow-soft ring-1 ring-neutral-200' : 'text-neutral-500 hover:text-neutral-900',
            )}
          >
            {item.label}
          </button>
        )
      })}
    </div>
  )
}
