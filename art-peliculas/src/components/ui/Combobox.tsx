import { useEffect, useId, useMemo, useRef, useState } from 'react'
import { Check, ChevronsUpDown, X } from 'lucide-react'
import { cn } from '@/lib/cn'
import { Spinner } from './Spinner'

export interface ComboOption {
  value: string
  label: string
  description?: string
  keywords?: string
}

interface ComboboxProps {
  value: string | null
  onChange: (value: string | null, option: ComboOption | null) => void
  options: ComboOption[]
  placeholder?: string
  emptyText?: string
  loading?: boolean
  disabled?: boolean
  /** Busca no servidor: quando informado, a filtragem local é desativada. */
  onSearchChange?: (term: string) => void
  /** Rótulo exibido quando o valor selecionado ainda não está nas opções carregadas. */
  selectedLabel?: string
  clearable?: boolean
  id?: string
  className?: string
  'aria-invalid'?: boolean
  'aria-describedby'?: string
}

function normalize(s: string) {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
}

export function Combobox({
  value,
  onChange,
  options,
  placeholder = 'Selecione…',
  emptyText = 'Nenhum resultado.',
  loading,
  disabled,
  onSearchChange,
  selectedLabel,
  clearable = true,
  id,
  className,
  ...aria
}: ComboboxProps) {
  const [open, setOpen] = useState(false)
  const [term, setTerm] = useState('')
  const [active, setActive] = useState(0)
  const rootRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const listId = useId()

  const selected = options.find((o) => o.value === value) ?? null
  const display = selected?.label ?? (value ? selectedLabel ?? '' : '')

  const filtered = useMemo(() => {
    if (onSearchChange || !term.trim()) return options
    const t = normalize(term.trim())
    return options.filter((o) => normalize(`${o.label} ${o.description ?? ''} ${o.keywords ?? ''}`).includes(t))
  }, [options, term, onSearchChange])

  useEffect(() => {
    if (!open) return
    const onDoc = (e: MouseEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [open])

  useEffect(() => setActive(0), [term, open])

  const choose = (opt: ComboOption) => {
    onChange(opt.value, opt)
    setOpen(false)
    setTerm('')
    onSearchChange?.('')
  }

  return (
    <div ref={rootRef} className={cn('relative', className)}>
      <div className="relative">
        <input
          ref={inputRef}
          id={id}
          role="combobox"
          aria-expanded={open}
          aria-controls={listId}
          aria-autocomplete="list"
          autoComplete="off"
          disabled={disabled}
          className="field-control h-10 pr-16"
          placeholder={display || placeholder}
          value={open ? term : display}
          onFocus={() => setOpen(true)}
          onClick={() => setOpen(true)}
          onChange={(e) => {
            setTerm(e.target.value)
            setOpen(true)
            onSearchChange?.(e.target.value)
          }}
          onKeyDown={(e) => {
            if (e.key === 'ArrowDown') {
              e.preventDefault()
              setOpen(true)
              setActive((a) => Math.min(a + 1, filtered.length - 1))
            } else if (e.key === 'ArrowUp') {
              e.preventDefault()
              setActive((a) => Math.max(a - 1, 0))
            } else if (e.key === 'Enter' && open) {
              e.preventDefault()
              const opt = filtered[active]
              if (opt) choose(opt)
            } else if (e.key === 'Escape' && open) {
              e.preventDefault()
              e.stopPropagation()
              setOpen(false)
            } else if (e.key === 'Tab') {
              setOpen(false)
            }
          }}
          {...aria}
        />
        <div className="absolute inset-y-0 right-0 flex items-center gap-0.5 pr-2">
          {loading && <Spinner className="h-3.5 w-3.5 text-neutral-400" />}
          {clearable && value && !disabled && (
            <button
              type="button"
              onClick={() => {
                onChange(null, null)
                setTerm('')
                inputRef.current?.focus()
              }}
              className="rounded p-1 text-neutral-400 hover:text-neutral-900"
              aria-label="Limpar seleção"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          )}
          <ChevronsUpDown className="pointer-events-none h-4 w-4 text-neutral-400" strokeWidth={1.75} />
        </div>
      </div>
      {open && !disabled && (
        <ul
          id={listId}
          role="listbox"
          className="scrollbar-thin absolute z-40 mt-1 max-h-72 w-full animate-fade-in overflow-y-auto rounded-lg border border-neutral-200 bg-white p-1 shadow-lift"
        >
          {filtered.length === 0 ? (
            <li className="px-3 py-6 text-center text-sm text-neutral-500">{loading ? 'Buscando…' : emptyText}</li>
          ) : (
            filtered.map((opt, i) => (
              <li
                key={opt.value}
                role="option"
                aria-selected={opt.value === value}
                onMouseEnter={() => setActive(i)}
                onMouseDown={(e) => {
                  e.preventDefault()
                  choose(opt)
                }}
                className={cn(
                  'flex cursor-pointer items-center gap-2 rounded-md px-2.5 py-2 text-sm',
                  i === active ? 'bg-neutral-100' : 'bg-white',
                )}
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium text-neutral-900">{opt.label}</p>
                  {opt.description && <p className="truncate text-xs text-neutral-500">{opt.description}</p>}
                </div>
                {opt.value === value && <Check className="h-4 w-4 shrink-0 text-neutral-900" />}
              </li>
            ))
          )}
        </ul>
      )}
    </div>
  )
}
