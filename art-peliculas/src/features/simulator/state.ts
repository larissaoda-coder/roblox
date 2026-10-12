import { ZONES } from '@/lib/constants'
import { vltToOpacity } from '@/lib/tint'
import type { Film, GlassZone, SimulationConfig } from '@/types/domain'
import type { TintVisual } from '@/features/three/materials'

export type ZoneSetting = { kind: 'none' } | { kind: 'film'; filmId: string; vlt: number } | { kind: 'custom'; vlt: number }
export type TintState = Record<GlassZone, ZoneSetting>

export const EMPTY_STATE: TintState = {
  para_brisa: { kind: 'none' },
  dianteiros: { kind: 'none' },
  traseiros: { kind: 'none' },
  vidro_traseiro: { kind: 'none' },
}

export function zoneVlt(s: ZoneSetting): number | null {
  return s.kind === 'none' ? null : s.vlt
}

/** Converte o estado da tela no formato salvo no banco (somente zonas com película). */
export function stateToConfig(state: TintState): SimulationConfig {
  const config: SimulationConfig = {}
  for (const z of ZONES) {
    const s = state[z]
    if (s.kind === 'none') continue
    config[z] = { vlt: s.vlt, film_id: s.kind === 'film' ? s.filmId : null }
  }
  return config
}

export function configToState(config: SimulationConfig, films: Film[]): TintState {
  const state: TintState = { ...EMPTY_STATE }
  for (const z of ZONES) {
    const c = config[z]
    if (!c) continue
    const film = c.film_id ? films.find((f) => f.id === c.film_id) : undefined
    state[z] = film ? { kind: 'film', filmId: film.id, vlt: film.vlt_percent } : { kind: 'custom', vlt: c.vlt }
  }
  return state
}

export function stateToVisual(state: TintState, films: Film[]): TintVisual {
  const visual: TintVisual = {}
  for (const z of ZONES) {
    const s = state[z]
    if (s.kind === 'none') continue
    const film = s.kind === 'film' ? films.find((f) => f.id === s.filmId) : undefined
    visual[z] = { opacity: vltToOpacity(s.vlt), finish: film?.finish ?? 'neutra' }
  }
  return visual
}

export function hasAnyTint(state: TintState) {
  return ZONES.some((z) => state[z].kind !== 'none')
}
