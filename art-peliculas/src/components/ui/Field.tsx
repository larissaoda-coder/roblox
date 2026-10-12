import { cloneElement, isValidElement, useId, type ReactElement, type ReactNode } from 'react'
import { AlertCircle } from 'lucide-react'
import { cn } from '@/lib/cn'

interface FieldProps {
  label?: string
  hint?: ReactNode
  error?: string
  required?: boolean
  className?: string
  children: ReactNode
}

/** Rótulo + controle + mensagem de erro/ajuda, com acessibilidade (aria-invalid/aria-describedby). */
export function Field({ label, hint, error, required, className, children }: FieldProps) {
  const id = useId()
  const describedBy = error ? `${id}-error` : hint ? `${id}-hint` : undefined
  const child = isValidElement(children)
    ? cloneElement(children as ReactElement<Record<string, unknown>>, {
        id: (children.props as { id?: string }).id ?? id,
        'aria-invalid': error ? true : undefined,
        'aria-describedby': describedBy,
      })
    : children

  return (
    <div className={cn('space-y-1.5', className)}>
      {label && (
        <label htmlFor={(isValidElement(children) && (children.props as { id?: string }).id) || id} className="block text-[13px] font-medium text-neutral-800">
          {label}
          {required && <span className="ml-0.5 text-neutral-400">*</span>}
        </label>
      )}
      {child}
      {error ? (
        <p id={`${id}-error`} className="flex items-start gap-1.5 text-xs font-medium text-neutral-900" role="alert">
          <AlertCircle className="mt-px h-3.5 w-3.5 shrink-0" strokeWidth={2} />
          {error}
        </p>
      ) : hint ? (
        <p id={`${id}-hint`} className="text-xs text-neutral-500">
          {hint}
        </p>
      ) : null}
    </div>
  )
}

export function FormError({ message }: { message?: string | null }) {
  if (!message) return null
  return (
    <div role="alert" className="flex animate-fade-in items-start gap-2.5 rounded-md border border-neutral-900 bg-neutral-50 px-3.5 py-3 text-sm text-neutral-900">
      <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" strokeWidth={2} />
      <span>{message}</span>
    </div>
  )
}

export function FormSuccess({ message }: { message?: string | null }) {
  if (!message) return null
  return (
    <div role="status" className="flex animate-fade-in items-start gap-2.5 rounded-md bg-neutral-950 px-3.5 py-3 text-sm text-white">
      <svg viewBox="0 0 24 24" className="mt-0.5 h-4 w-4 shrink-0" fill="none" stroke="currentColor" strokeWidth="2.25" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <path d="M20 6 9 17l-5-5" />
      </svg>
      <span>{message}</span>
    </div>
  )
}
