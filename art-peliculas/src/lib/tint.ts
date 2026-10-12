import type { GlassZone, SimulationConfig } from '@/types/domain'

/**
 * Converte a transmissão luminosa (VLT %) em opacidade da camada escura aplicada ao vidro.
 * Usa uma curva levemente não linear para que películas claras (70–80%) continuem discretas
 * e as escuras (5–20%) fiquem densas sem apagar totalmente os reflexos do vidro.
 */
export function vltToOpacity(vlt: number) {
  const t = Math.min(100, Math.max(0, vlt)) / 100
  return Math.min(0.94, Math.pow(1 - t, 1.15) * 0.97)
}

export interface LegalLimits {
  windshield: number
  front: number
  rear: number
}

export function legalMinimum(zone: GlassZone, limits: LegalLimits) {
  if (zone === 'para_brisa') return limits.windshield
  if (zone === 'dianteiros') return limits.front
  return limits.rear
}

export function isBelowLegal(zone: GlassZone, vlt: number, limits: LegalLimits) {
  return vlt < legalMinimum(zone, limits)
}

export function configHasTint(config: SimulationConfig) {
  return Object.values(config).some((z) => z && z.vlt < 100)
}
