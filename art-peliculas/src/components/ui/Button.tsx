import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react'
import { cn } from '@/lib/cn'
import { Spinner } from './Spinner'

type Variant = 'primary' | 'secondary' | 'ghost' | 'outline-dark' | 'link'
type Size = 'sm' | 'md' | 'lg' | 'icon' | 'icon-sm'

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  loading?: boolean
  icon?: ReactNode
}

const variants: Record<Variant, string> = {
  primary: 'bg-neutral-950 text-white shadow-soft hover:bg-neutral-800 active:bg-neutral-900 disabled:bg-neutral-300',
  secondary:
    'border border-neutral-300 bg-white text-neutral-900 shadow-soft hover:border-neutral-400 hover:bg-neutral-50 disabled:text-neutral-400',
  ghost: 'text-neutral-700 hover:bg-neutral-100 hover:text-neutral-950 disabled:text-neutral-400',
  'outline-dark':
    'border border-neutral-900 bg-white text-neutral-950 hover:bg-neutral-950 hover:text-white disabled:border-neutral-300 disabled:text-neutral-400',
  link: 'px-0 text-neutral-900 underline-offset-4 hover:underline disabled:text-neutral-400',
}

const sizes: Record<Size, string> = {
  sm: 'h-8 gap-1.5 rounded-md px-3 text-[13px]',
  md: 'h-10 gap-2 rounded-md px-4 text-sm',
  lg: 'h-11 gap-2 rounded-lg px-5 text-[15px]',
  icon: 'h-10 w-10 rounded-md',
  'icon-sm': 'h-8 w-8 rounded-md',
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'primary', size = 'md', loading = false, icon, className, children, disabled, type = 'button', ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={cn(
        'inline-flex shrink-0 select-none items-center justify-center whitespace-nowrap font-medium transition-all duration-150 disabled:cursor-not-allowed',
        variants[variant],
        variant !== 'link' && sizes[size],
        className,
      )}
      {...props}
    >
      {loading ? <Spinner className="h-4 w-4" /> : icon}
      {children}
    </button>
  )
})
