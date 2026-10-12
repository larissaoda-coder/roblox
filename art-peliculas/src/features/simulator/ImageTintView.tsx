import { useId } from 'react'
import { ZONES } from '@/lib/constants'
import { toSvgPoints } from '@/lib/geometry'
import type { GlassMasks } from '@/types/domain'
import type { TintVisual } from '@/features/three/materials'
import { CompareHandle } from './CompareHandle'

/**
 * Simulação sobre imagem: a película é aplicada somente dentro dos polígonos dos vidros
 * (multiplicação em preto), preservando a carroceria e o restante da foto.
 */
export function ImageTintView({
  url,
  width,
  height,
  masks,
  visual,
  compare,
  split,
  onSplitChange,
  alt,
}: {
  url: string
  width: number
  height: number
  masks: GlassMasks
  visual: TintVisual
  compare: boolean
  split: number
  onSplitChange: (v: number) => void
  alt: string
}) {
  const uid = useId().replace(/:/g, '')
  const feather = Math.max(0.6, width / 1400)

  return (
    <div className="relative w-full bg-neutral-100" style={{ aspectRatio: `${width} / ${height}` }}>
      <svg viewBox={`0 0 ${width} ${height}`} className="absolute inset-0 h-full w-full" role="img" aria-label={alt}>
        <defs>
          <filter id={`feather-${uid}`} x="-2%" y="-2%" width="104%" height="104%">
            <feGaussianBlur stdDeviation={feather} />
          </filter>
          <linearGradient id={`sheen-${uid}`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#ffffff" stopOpacity="0.55" />
            <stop offset="0.45" stopColor="#ffffff" stopOpacity="0.08" />
            <stop offset="1" stopColor="#ffffff" stopOpacity="0.3" />
          </linearGradient>
          <clipPath id={`after-${uid}`}>
            <rect x={compare ? split * width : 0} y={0} width={width} height={height} />
          </clipPath>
        </defs>
        <image href={url} x={0} y={0} width={width} height={height} />
        <g clipPath={`url(#after-${uid})`}>
          <g filter={`url(#feather-${uid})`} style={{ mixBlendMode: 'multiply' }}>
            {ZONES.map((z) =>
              (masks[z] ?? []).map((poly, i) => (
                <polygon
                  key={`${z}-${i}`}
                  points={toSvgPoints(poly, width, height)}
                  fill="#0a0a0a"
                  style={{ fillOpacity: visual[z]?.opacity ?? 0, transition: 'fill-opacity 350ms ease' }}
                />
              )),
            )}
          </g>
          <g style={{ mixBlendMode: 'screen' }}>
            {ZONES.filter((z) => visual[z]?.finish === 'refletiva').map((z) =>
              (masks[z] ?? []).map((poly, i) => (
                <polygon
                  key={`s-${z}-${i}`}
                  points={toSvgPoints(poly, width, height)}
                  fill={`url(#sheen-${uid})`}
                  style={{ opacity: Math.min(0.55, (visual[z]?.opacity ?? 0) * 0.6), transition: 'opacity 350ms ease' }}
                />
              )),
            )}
          </g>
        </g>
      </svg>
      {compare && <CompareHandle value={split} onChange={onSplitChange} />}
    </div>
  )
}
