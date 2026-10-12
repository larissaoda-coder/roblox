import { useCallback, useEffect, useMemo, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react'
import { Check, Eye, EyeOff, Minus, Plus, Trash2, Undo2, X } from 'lucide-react'
import { Button, Segmented } from '@/components/ui'
import { ZONES, ZONE_SHORT } from '@/lib/constants'
import { centroid, clamp01, cleanMasks, distance, toSvgPoints } from '@/lib/geometry'
import { vltToOpacity } from '@/lib/tint'
import { cn } from '@/lib/cn'
import type { GlassMasks, GlassZone, Point, Polygon } from '@/types/domain'

interface Props {
  imageUrl: string
  width: number
  height: number
  initial: GlassMasks
  saving?: boolean
  onSave: (masks: GlassMasks) => void
  onCancel: () => void
}

type Selection = { zone: GlassZone; index: number } | null
type Drag = { zone: GlassZone; poly: number; point: number } | null

const ZOOMS = [1, 1.5, 2, 3]

/**
 * Editor de máscaras: o administrador desenha polígonos sobre as áreas envidraçadas
 * de cada zona. As coordenadas são salvas normalizadas (0–1), independentes da resolução.
 */
export function MaskEditor({ imageUrl, width, height, initial, saving, onSave, onCancel }: Props) {
  const [masks, setMasks] = useState<GlassMasks>(() => structuredClone(initial ?? {}))
  const [history, setHistory] = useState<GlassMasks[]>([])
  const [zone, setZone] = useState<GlassZone>('para_brisa')
  const [draft, setDraft] = useState<Polygon>([])
  const [selected, setSelected] = useState<Selection>(null)
  const [drag, setDrag] = useState<Drag>(null)
  const [preview, setPreview] = useState(false)
  const [zoom, setZoom] = useState(1)
  const [hover, setHover] = useState<Point | null>(null)
  const svgRef = useRef<SVGSVGElement>(null)
  const [pxScale, setPxScale] = useState(1)

  // Mantém alças e traços com tamanho constante na tela, independentemente do zoom.
  useEffect(() => {
    const svg = svgRef.current
    if (!svg) return
    const update = () => setPxScale(width / Math.max(1, svg.getBoundingClientRect().width))
    update()
    const ro = new ResizeObserver(update)
    ro.observe(svg)
    return () => ro.disconnect()
  }, [width, zoom])

  const commit = useCallback(
    (next: GlassMasks) => {
      setHistory((h) => [...h.slice(-49), masks])
      setMasks(next)
    },
    [masks],
  )

  const toPoint = (e: { clientX: number; clientY: number }): Point => {
    const svg = svgRef.current!
    const rect = svg.getBoundingClientRect()
    return [clamp01((e.clientX - rect.left) / rect.width), clamp01((e.clientY - rect.top) / rect.height)]
  }

  const closeDraft = useCallback(() => {
    if (draft.length < 3) return
    const list = [...(masks[zone] ?? []), draft]
    commit({ ...masks, [zone]: list })
    setSelected({ zone, index: list.length - 1 })
    setDraft([])
  }, [draft, masks, zone, commit])

  const undo = useCallback(() => {
    if (draft.length) {
      setDraft((d) => d.slice(0, -1))
      return
    }
    setHistory((h) => {
      if (!h.length) return h
      setMasks(h[h.length - 1])
      setSelected(null)
      return h.slice(0, -1)
    })
  }, [draft.length])

  const deleteSelected = useCallback(() => {
    if (!selected) return
    const list = (masks[selected.zone] ?? []).filter((_, i) => i !== selected.index)
    commit({ ...masks, [selected.zone]: list })
    setSelected(null)
  }, [selected, masks, commit])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement
      if (target.closest('input, textarea, select')) return
      if (e.key === 'Enter') {
        e.preventDefault()
        closeDraft()
      } else if (e.key === 'Escape' && draft.length) {
        e.stopPropagation()
        setDraft([])
      } else if ((e.key === 'z' || e.key === 'Z') && (e.ctrlKey || e.metaKey)) {
        e.preventDefault()
        undo()
      } else if (e.key === 'Backspace' || e.key === 'Delete') {
        if (draft.length) setDraft((d) => d.slice(0, -1))
        else deleteSelected()
      }
    }
    window.addEventListener('keydown', onKey, true)
    return () => window.removeEventListener('keydown', onKey, true)
  }, [closeDraft, undo, deleteSelected, draft.length])

  const onBackgroundDown = (e: ReactPointerEvent) => {
    if (preview || e.button !== 0) return
    const p = toPoint(e)
    if (draft.length >= 3 && distance(p, draft[0]) < 12 * (pxScale / width)) {
      closeDraft()
      return
    }
    setSelected(null)
    setDraft((d) => [...d, p])
  }

  const onPolygonDown = (e: ReactPointerEvent, z: GlassZone, index: number) => {
    if (preview || draft.length) return
    e.stopPropagation()
    setZone(z)
    setSelected({ zone: z, index })
  }

  const onVertexDown = (e: ReactPointerEvent, z: GlassZone, poly: number, point: number) => {
    if (preview) return
    e.stopPropagation()
    ;(e.target as Element).setPointerCapture?.(e.pointerId)
    setHistory((h) => [...h.slice(-49), masks])
    setDrag({ zone: z, poly, point })
  }

  const onMove = (e: ReactPointerEvent) => {
    const p = toPoint(e)
    if (drag) {
      setMasks((m) => {
        const polys = (m[drag.zone] ?? []).map((poly, pi) => (pi === drag.poly ? poly.map((pt, i) => (i === drag.point ? p : pt)) : poly))
        return { ...m, [drag.zone]: polys }
      })
    } else if (draft.length) {
      setHover(p)
    }
  }

  const counts = useMemo(() => Object.fromEntries(ZONES.map((z) => [z, masks[z]?.length ?? 0])) as Record<GlassZone, number>, [masks])
  const r = 6 * pxScale
  const stroke = 1.75

  const zoneLayer = (z: GlassZone) =>
    (masks[z] ?? []).map((poly, i) => {
      const isActiveZone = z === zone
      const isSelected = selected?.zone === z && selected.index === i
      const [cx, cy] = centroid(poly)
      return (
        <g key={`${z}-${i}`}>
          <polygon
            points={toSvgPoints(poly, width, height)}
            onPointerDown={(e) => onPolygonDown(e, z, i)}
            className={cn(!preview && !draft.length && 'cursor-pointer')}
            fill={preview ? '#0a0a0a' : isActiveZone ? '#0a0a0a' : '#ffffff'}
            fillOpacity={preview ? vltToOpacity(20) : isActiveZone ? (isSelected ? 0.45 : 0.32) : 0.28}
            stroke={preview ? 'none' : '#0a0a0a'}
            strokeWidth={(isSelected ? 2.5 : stroke) * pxScale}
            strokeDasharray={isActiveZone ? undefined : `${5 * pxScale} ${4 * pxScale}`}
            strokeLinejoin="round"
            style={preview ? { mixBlendMode: 'multiply' } : undefined}
          />
          {!preview && (
            <text
              x={cx * width}
              y={cy * height}
              textAnchor="middle"
              dominantBaseline="middle"
              fontSize={11 * pxScale}
              fontWeight={600}
              fill={isActiveZone ? '#ffffff' : '#0a0a0a'}
              stroke={isActiveZone ? '#0a0a0a' : '#ffffff'}
              strokeWidth={3 * pxScale}
              paintOrder="stroke"
              pointerEvents="none"
            >
              {ZONE_SHORT[z]}
            </text>
          )}
          {!preview &&
            isSelected &&
            poly.map(([x, y], pi) => (
              <circle
                key={pi}
                cx={x * width}
                cy={y * height}
                r={r}
                fill="#ffffff"
                stroke="#0a0a0a"
                strokeWidth={2 * pxScale}
                className="cursor-move"
                onPointerDown={(e) => onVertexDown(e, z, i, pi)}
              />
            ))}
        </g>
      )
    })

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <Segmented
          ariaLabel="Zona de vidro"
          value={zone}
          onChange={(z) => {
            setZone(z)
            setSelected(null)
            setDraft([])
          }}
          items={ZONES.map((z) => ({ value: z, label: `${ZONE_SHORT[z]}${counts[z] ? ` (${counts[z]})` : ''}` }))}
          className="flex-wrap"
        />
        <div className="flex flex-wrap items-center gap-1.5">
          <Button size="sm" variant="secondary" icon={<Check className="h-3.5 w-3.5" />} disabled={draft.length < 3} onClick={closeDraft}>
            Fechar polígono
          </Button>
          <Button size="sm" variant="ghost" icon={<Undo2 className="h-3.5 w-3.5" />} disabled={!draft.length && !history.length} onClick={undo}>
            Desfazer
          </Button>
          <Button size="sm" variant="ghost" icon={<Trash2 className="h-3.5 w-3.5" />} disabled={!selected} onClick={deleteSelected}>
            Excluir polígono
          </Button>
          <Button
            size="sm"
            variant="ghost"
            icon={<X className="h-3.5 w-3.5" />}
            disabled={!counts[zone]}
            onClick={() => {
              commit({ ...masks, [zone]: [] })
              setSelected(null)
            }}
          >
            Limpar zona
          </Button>
          <Button size="sm" variant={preview ? 'primary' : 'secondary'} icon={preview ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />} onClick={() => setPreview((p) => !p)}>
            {preview ? 'Voltar à edição' : 'Pré-visualizar'}
          </Button>
        </div>
      </div>

      <div className="flex items-center justify-between gap-3 text-xs text-neutral-500">
        <p>
          {draft.length
            ? `${draft.length} ponto(s). Clique no primeiro ponto ou pressione Enter para fechar; Esc cancela.`
            : 'Clique nos cantos do vidro para desenhar. Selecione um polígono para arrastar os pontos. Ctrl+Z desfaz.'}
        </p>
        <div className="flex shrink-0 items-center gap-1">
          <Button size="icon-sm" variant="ghost" aria-label="Diminuir zoom" disabled={zoom === ZOOMS[0]} onClick={() => setZoom(ZOOMS[Math.max(0, ZOOMS.indexOf(zoom) - 1)])}>
            <Minus className="h-3.5 w-3.5" />
          </Button>
          <span className="w-10 text-center num">{Math.round(zoom * 100)}%</span>
          <Button size="icon-sm" variant="ghost" aria-label="Aumentar zoom" disabled={zoom === ZOOMS[ZOOMS.length - 1]} onClick={() => setZoom(ZOOMS[Math.min(ZOOMS.length - 1, ZOOMS.indexOf(zoom) + 1)])}>
            <Plus className="h-3.5 w-3.5" />
          </Button>
        </div>
      </div>

      <div className="scrollbar-thin max-h-[62vh] overflow-auto rounded-lg border border-neutral-200 bg-neutral-100">
        <div style={{ width: `${zoom * 100}%` }} className="mx-auto">
          <svg
            ref={svgRef}
            viewBox={`0 0 ${width} ${height}`}
            className={cn('block h-auto w-full select-none', !preview && 'cursor-crosshair')}
            style={{ touchAction: 'none' }}
            onPointerDown={onBackgroundDown}
            onPointerMove={onMove}
            onPointerUp={() => setDrag(null)}
            onPointerLeave={() => setHover(null)}
            role="application"
            aria-label="Área de desenho das máscaras dos vidros"
          >
            <image href={imageUrl} x={0} y={0} width={width} height={height} />
            {ZONES.filter((z) => z !== zone).map(zoneLayer)}
            {zoneLayer(zone)}
            {!preview && draft.length > 0 && (
              <g pointerEvents="none">
                <polyline
                  points={toSvgPoints(hover ? [...draft, hover] : draft, width, height)}
                  fill="#0a0a0a"
                  fillOpacity={0.15}
                  stroke="#0a0a0a"
                  strokeWidth={stroke * pxScale}
                  strokeDasharray={`${6 * pxScale} ${4 * pxScale}`}
                />
                {draft.map(([x, y], i) => (
                  <circle key={i} cx={x * width} cy={y * height} r={i === 0 ? r * 1.4 : r * 0.8} fill={i === 0 ? '#0a0a0a' : '#ffffff'} stroke="#0a0a0a" strokeWidth={2 * pxScale} />
                ))}
              </g>
            )}
          </svg>
        </div>
      </div>

      <div className="flex flex-col-reverse gap-2 border-t border-neutral-200 pt-4 sm:flex-row sm:justify-end">
        <Button variant="secondary" onClick={onCancel}>
          Cancelar
        </Button>
        <Button loading={saving} onClick={() => onSave(cleanMasks(masks))} disabled={draft.length > 0}>
          Salvar máscaras
        </Button>
      </div>
    </div>
  )
}
