import { useRef, useState, type PointerEvent as ReactPointerEvent } from 'react'
import { ChevronsLeftRight } from 'lucide-react'

/** Divisória arrastável "antes / depois" sobreposta à visualização. */
export function CompareHandle({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  const ref = useRef<HTMLDivElement>(null)
  const [dragging, setDragging] = useState(false)

  const update = (e: ReactPointerEvent) => {
    const rect = ref.current?.getBoundingClientRect()
    if (!rect) return
    onChange(Math.min(0.98, Math.max(0.02, (e.clientX - rect.left) / rect.width)))
  }

  return (
    <div ref={ref} className="pointer-events-none absolute inset-0 select-none">
      <span className="absolute left-3 top-3 rounded bg-white/90 px-2 py-1 text-[11px] font-semibold uppercase tracking-wide text-neutral-800 shadow-soft">Original</span>
      <span className="absolute right-3 top-3 rounded bg-neutral-950/90 px-2 py-1 text-[11px] font-semibold uppercase tracking-wide text-white shadow-soft">Simulação</span>
      <div className="absolute inset-y-0 w-px bg-white shadow-[0_0_0_1px_rgba(0,0,0,0.25)]" style={{ left: `${value * 100}%` }} />
      <button
        type="button"
        role="slider"
        aria-label="Divisão entre original e simulação"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(value * 100)}
        className={`pointer-events-auto absolute top-1/2 flex h-10 w-10 -translate-x-1/2 -translate-y-1/2 cursor-ew-resize items-center justify-center rounded-full border border-neutral-300 bg-white text-neutral-900 shadow-lift transition-transform ${dragging ? 'scale-110' : 'hover:scale-105'}`}
        style={{ left: `${value * 100}%`, touchAction: 'none' }}
        onPointerDown={(e) => {
          e.preventDefault()
          e.stopPropagation()
          e.currentTarget.setPointerCapture(e.pointerId)
          setDragging(true)
        }}
        onPointerMove={(e) => dragging && update(e)}
        onPointerUp={() => setDragging(false)}
        onKeyDown={(e) => {
          if (e.key === 'ArrowLeft') onChange(Math.max(0.02, value - 0.05))
          if (e.key === 'ArrowRight') onChange(Math.min(0.98, value + 0.05))
        }}
      >
        <ChevronsLeftRight className="h-4 w-4" />
      </button>
    </div>
  )
}
