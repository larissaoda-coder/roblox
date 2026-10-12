import { useState } from 'react'
import { vltToOpacity } from '@/lib/tint'
import { Segmented } from '@/components/ui'

const LEVELS = [80, 70, 50, 35, 20, 5]

/**
 * Ilustração genérica (silhueta lateral) usada apenas na página inicial para explicar
 * os níveis de transmissão luminosa. Não representa nenhum modelo de veículo específico.
 */
export function TintIllustration() {
  const [vlt, setVlt] = useState(35)
  const opacity = vltToOpacity(vlt)

  return (
    <figure className="rounded-2xl border border-neutral-200 bg-neutral-50 p-5 shadow-soft sm:p-7">
      <svg viewBox="0 0 600 210" className="h-auto w-full" role="img" aria-label={`Silhueta ilustrativa com película de ${vlt}% de transmissão luminosa`}>
        <defs>
          <linearGradient id="glass" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="#f5f5f5" />
            <stop offset="1" stopColor="#d4d4d4" />
          </linearGradient>
        </defs>
        <ellipse cx="300" cy="196" rx="270" ry="7" fill="#0a0a0a" opacity="0.06" />
        <path
          d="M40 160 L36 128 Q36 112 52 108 L120 100 L200 62 Q214 52 236 50 L360 50 Q380 51 392 60 L452 98 L540 108 Q566 112 570 128 L572 150 Q572 162 560 162 L522 162 A42 42 0 0 0 438 162 L168 162 A42 42 0 0 0 84 162 L52 162 Q40 162 40 160 Z"
          fill="#ffffff"
          stroke="#0a0a0a"
          strokeWidth="2"
          strokeLinejoin="round"
        />
        <g>
          <path d="M186 100 L220 64 Q226 59 238 59 L312 59 L312 100 Z" fill="url(#glass)" />
          <path d="M324 59 L376 59 Q386 60 393 66 L434 100 L324 100 Z" fill="url(#glass)" />
          <path d="M132 100 L198 66 L206 66 L176 100 Z" fill="url(#glass)" />
          <g style={{ transition: 'opacity 400ms ease' }} opacity={opacity}>
            <path d="M186 100 L220 64 Q226 59 238 59 L312 59 L312 100 Z" fill="#0a0a0a" />
            <path d="M324 59 L376 59 Q386 60 393 66 L434 100 L324 100 Z" fill="#0a0a0a" />
            <path d="M132 100 L198 66 L206 66 L176 100 Z" fill="#0a0a0a" />
          </g>
          <path d="M186 100 L220 64 Q226 59 238 59 L312 59 L312 100 Z M324 59 L376 59 Q386 60 393 66 L434 100 L324 100 Z" fill="none" stroke="#0a0a0a" strokeWidth="1.5" strokeLinejoin="round" />
          <path d="M226 64 L262 64 L236 92 Z" fill="#ffffff" opacity="0.35" />
          <path d="M340 64 L366 64 L344 90 Z" fill="#ffffff" opacity="0.3" />
        </g>
        <path d="M318 104 L318 150 M210 110 L250 110 M352 110 L392 110" stroke="#0a0a0a" strokeWidth="1.5" strokeLinecap="round" opacity="0.5" />
        {[126, 480].map((cx) => (
          <g key={cx}>
            <circle cx={cx} cy="162" r="34" fill="#171717" />
            <circle cx={cx} cy="162" r="19" fill="#e5e5e5" stroke="#0a0a0a" strokeWidth="1.5" />
            <circle cx={cx} cy="162" r="4" fill="#0a0a0a" />
          </g>
        ))}
      </svg>
      <figcaption className="mt-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-sm font-medium text-neutral-950">Transmissão luminosa: {vlt}%</p>
          <p className="text-xs text-neutral-500">Ilustração genérica. No sistema, a simulação usa imagens e modelos 3D cadastrados.</p>
        </div>
        <Segmented
          ariaLabel="Nível de película"
          size="sm"
          value={vlt}
          onChange={setVlt}
          items={LEVELS.map((l) => ({ value: l, label: `${l}%` }))}
        />
      </figcaption>
    </figure>
  )
}
