import { AlertTriangle, CheckCircle2, EyeOff } from 'lucide-react'
import { Select } from '@/components/ui'
import { VLT_PRESETS, ZONES, ZONE_LABELS } from '@/lib/constants'
import { formatCurrency } from '@/lib/format'
import { PRICE_UNIT_LABELS } from '@/lib/constants'
import { isBelowLegal, legalMinimum, type LegalLimits } from '@/lib/tint'
import { cn } from '@/lib/cn'
import type { Film, GlassZone } from '@/types/domain'
import { filmLabel } from '@/features/films/api'
import type { TintState, ZoneSetting } from './state'

interface Props {
  state: TintState
  onChange: (zone: GlassZone, setting: ZoneSetting) => void
  films: Film[]
  recommendedIds: Set<string>
  limits: LegalLimits
  /** Zonas sem representação visual na mídia atual. */
  hiddenZones: Set<GlassZone>
}

function settingValue(s: ZoneSetting) {
  return s.kind === 'none' ? '' : s.kind === 'custom' ? 'custom' : s.filmId
}

export function FilmSelect({
  value,
  onChange,
  films,
  recommendedIds,
  id,
  allowCustom = true,
  emptyLabel = 'Sem película',
  placeholder,
}: {
  value: string
  onChange: (value: string) => void
  films: Film[]
  recommendedIds: Set<string>
  id?: string
  allowCustom?: boolean
  emptyLabel?: string
  placeholder?: string
}) {
  const recommended = films.filter((f) => recommendedIds.has(f.id))
  const others = films.filter((f) => !recommendedIds.has(f.id))
  const option = (f: Film) => (
    <option key={f.id} value={f.id}>
      {filmLabel(f)} — {formatCurrency(f.price)} {PRICE_UNIT_LABELS[f.price_unit]}
    </option>
  )
  return (
    <Select id={id} value={value} onChange={(e) => onChange(e.target.value)} className="h-9 text-[13px]">
      {placeholder && (
        <option value="__" disabled>
          {placeholder}
        </option>
      )}
      <option value="">{emptyLabel}</option>
      {allowCustom && <option value="custom">Nível personalizado (sem produto)</option>}
      {recommended.length > 0 && <optgroup label="Indicadas para este veículo">{recommended.map(option)}</optgroup>}
      {others.length > 0 && <optgroup label={recommended.length ? 'Demais películas do catálogo' : 'Catálogo de películas'}>{others.map(option)}</optgroup>}
    </Select>
  )
}

export function ZoneControls({ state, onChange, films, recommendedIds, limits, hiddenZones }: Props) {
  return (
    <div className="divide-y divide-neutral-200">
      {ZONES.map((zone) => {
        const s = state[zone]
        const min = legalMinimum(zone, limits)
        const below = s.kind !== 'none' && isBelowLegal(zone, s.vlt, limits)
        const selectId = `zone-${zone}`
        return (
          <div key={zone} className="space-y-2.5 py-4 first:pt-0 last:pb-0" data-zone={zone}>
            <div className="flex items-center justify-between gap-2">
              <label htmlFor={selectId} className="text-sm font-semibold text-neutral-950">
                {ZONE_LABELS[zone]}
              </label>
              <span className="text-[11px] text-neutral-500">Ref. mínima {min.toLocaleString('pt-BR')}%</span>
            </div>
            <FilmSelect
              id={selectId}
              value={settingValue(s)}
              films={films}
              recommendedIds={recommendedIds}
              onChange={(v) => {
                if (!v) onChange(zone, { kind: 'none' })
                else if (v === 'custom') onChange(zone, { kind: 'custom', vlt: s.kind === 'none' ? 35 : s.vlt })
                else {
                  const film = films.find((f) => f.id === v)
                  if (film) onChange(zone, { kind: 'film', filmId: film.id, vlt: film.vlt_percent })
                }
              }}
            />
            {s.kind === 'custom' && (
              <div className="space-y-2">
                <div className="flex flex-wrap gap-1" role="group" aria-label={`Níveis para ${ZONE_LABELS[zone]}`}>
                  {VLT_PRESETS.map((p) => (
                    <button
                      key={p}
                      type="button"
                      onClick={() => onChange(zone, { kind: 'custom', vlt: p })}
                      className={cn(
                        'h-7 rounded-md border px-2.5 text-xs font-medium transition-colors',
                        s.vlt === p ? 'border-neutral-950 bg-neutral-950 text-white' : 'border-neutral-300 bg-white text-neutral-700 hover:border-neutral-500',
                      )}
                      aria-pressed={s.vlt === p}
                    >
                      {p}%
                    </button>
                  ))}
                </div>
                <input
                  type="range"
                  min={1}
                  max={95}
                  step={1}
                  value={s.vlt}
                  onChange={(e) => onChange(zone, { kind: 'custom', vlt: Number(e.target.value) })}
                  className="w-full accent-neutral-950"
                  aria-label={`Transmissão luminosa de ${ZONE_LABELS[zone]}`}
                />
              </div>
            )}
            <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs">
              {s.kind === 'none' ? (
                <span className="text-neutral-500">Vidro original</span>
              ) : (
                <>
                  <span className="font-medium text-neutral-900 num">Transmissão {s.vlt.toLocaleString('pt-BR')}%</span>
                  {below ? (
                    <span className="inline-flex items-center gap-1 font-medium text-neutral-900">
                      <AlertTriangle className="h-3.5 w-3.5" /> Abaixo da referência legal
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-neutral-500">
                      <CheckCircle2 className="h-3.5 w-3.5" /> Dentro da referência
                    </span>
                  )}
                </>
              )}
              {hiddenZones.has(zone) && (
                <span className="inline-flex items-center gap-1 text-neutral-400">
                  <EyeOff className="h-3.5 w-3.5" /> Não aparece nesta vista
                </span>
              )}
            </div>
          </div>
        )
      })}
    </div>
  )
}
