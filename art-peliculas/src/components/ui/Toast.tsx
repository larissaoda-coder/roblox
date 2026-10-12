import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { AlertCircle, CheckCircle2, Info, X } from 'lucide-react'
import { cn } from '@/lib/cn'

type ToastKind = 'success' | 'error' | 'info'
interface ToastItem {
  id: number
  kind: ToastKind
  message: string
  title?: string
}

interface ToastApi {
  success: (message: string, title?: string) => void
  error: (message: string, title?: string) => void
  info: (message: string, title?: string) => void
}

const ToastContext = createContext<ToastApi | null>(null)

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([])
  const nextId = useRef(1)

  const dismiss = useCallback((id: number) => setItems((list) => list.filter((t) => t.id !== id)), [])

  const push = useCallback(
    (kind: ToastKind, message: string, title?: string) => {
      const id = nextId.current++
      setItems((list) => [...list.slice(-3), { id, kind, message, title }])
      window.setTimeout(() => dismiss(id), kind === 'error' ? 7000 : 4500)
    },
    [dismiss],
  )

  const api = useMemo<ToastApi>(
    () => ({
      success: (m, t) => push('success', m, t),
      error: (m, t) => push('error', m, t),
      info: (m, t) => push('info', m, t),
    }),
    [push],
  )

  return (
    <ToastContext.Provider value={api}>
      {children}
      {createPortal(
        <div
          aria-live="polite"
          className="pointer-events-none fixed inset-x-0 bottom-0 z-[60] flex flex-col items-center gap-2 p-4 sm:inset-x-auto sm:bottom-auto sm:right-0 sm:top-0 sm:items-end sm:p-6"
        >
          {items.map((t) => (
            <div
              key={t.id}
              role={t.kind === 'error' ? 'alert' : 'status'}
              className={cn(
                'pointer-events-auto flex w-full max-w-sm animate-slide-in-right items-start gap-3 rounded-lg px-4 py-3 text-sm shadow-lift',
                t.kind === 'success' && 'bg-neutral-950 text-white',
                t.kind === 'error' && 'border border-neutral-900 bg-white text-neutral-950',
                t.kind === 'info' && 'border border-neutral-200 bg-white text-neutral-900',
              )}
            >
              {t.kind === 'success' && <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" strokeWidth={2} />}
              {t.kind === 'error' && <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" strokeWidth={2} />}
              {t.kind === 'info' && <Info className="mt-0.5 h-4 w-4 shrink-0" strokeWidth={2} />}
              <div className="min-w-0 flex-1">
                {t.title && <p className="font-semibold">{t.title}</p>}
                <p className={cn(t.title && 'mt-0.5', t.kind === 'success' ? 'text-neutral-200' : 'text-neutral-700', !t.title && t.kind === 'success' && 'text-white', !t.title && t.kind !== 'success' && 'text-neutral-900')}>
                  {t.message}
                </p>
              </div>
              <button
                type="button"
                onClick={() => dismiss(t.id)}
                className={cn('-mr-1 rounded p-0.5 opacity-60 transition-opacity hover:opacity-100')}
                aria-label="Fechar notificação"
              >
                <X className="h-4 w-4" strokeWidth={1.75} />
              </button>
            </div>
          ))}
        </div>,
        document.body,
      )}
    </ToastContext.Provider>
  )
}

export function useToast() {
  const ctx = useContext(ToastContext)
  if (!ctx) throw new Error('useToast deve ser usado dentro de ToastProvider')
  return ctx
}
