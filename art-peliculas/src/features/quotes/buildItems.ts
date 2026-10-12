import { ZONE_GLASS_COUNT, ZONE_LABELS, ZONES } from '@/lib/constants'
import type { Film, GlassZone, SimulationConfig } from '@/types/domain'

export interface EditorItem {
  kind: 'pelicula' | 'servico' | 'outro'
  film_id: string | null
  service_type_id: string | null
  glass_zones: GlassZone[]
  description: string
  quantity: string
  unit_price: string
  discount: string
}

export const toInput = (n: number) => (Number.isInteger(n) ? String(n) : n.toFixed(2)).replace('.', ',')

export function zonesText(zones: GlassZone[]) {
  return ZONES.filter((z) => zones.includes(z))
    .map((z) => ZONE_LABELS[z].toLowerCase())
    .join(', ')
}

export function filmDescription(film: Film, zones: GlassZone[]) {
  const name = [film.manufacturer, film.name, film.product_line].filter(Boolean).join(' ')
  const vlt = film.vlt_percent.toLocaleString('pt-BR')
  return `Película ${name} (${vlt}%)${zones.length ? ` — ${zonesText(zones)}` : ''}`.slice(0, 300)
}

/** Quantidade sugerida conforme a unidade de preço da película. */
export function suggestedQuantity(film: Pick<Film, 'price_unit'>, zones: GlassZone[]) {
  if (film.price_unit === 'vidro') return Math.max(1, zones.reduce((acc, z) => acc + ZONE_GLASS_COUNT[z], 0))
  return 1
}

export function filmUnitPrice(film: Film, overrides: Map<string, number | null>) {
  const o = overrides.get(film.id)
  return o !== undefined && o !== null ? o : film.price
}

export function filmItem(film: Film, zones: GlassZone[], overrides: Map<string, number | null>): EditorItem {
  return {
    kind: 'pelicula',
    film_id: film.id,
    service_type_id: null,
    glass_zones: zones,
    description: filmDescription(film, zones),
    quantity: toInput(suggestedQuantity(film, zones)),
    unit_price: toInput(filmUnitPrice(film, overrides)),
    discount: '',
  }
}

/**
 * Converte a configuração de uma simulação em itens de orçamento:
 * um item por película (agrupando as zonas) e um item por nível sem produto definido.
 */
export function itemsFromSimulation(config: SimulationConfig, films: Film[], overrides: Map<string, number | null>): EditorItem[] {
  const byFilm = new Map<string, GlassZone[]>()
  const byVlt = new Map<number, GlassZone[]>()
  for (const z of ZONES) {
    const c = config[z]
    if (!c) continue
    const film = c.film_id ? films.find((f) => f.id === c.film_id) : undefined
    if (film) byFilm.set(film.id, [...(byFilm.get(film.id) ?? []), z])
    else byVlt.set(c.vlt, [...(byVlt.get(c.vlt) ?? []), z])
  }
  const items: EditorItem[] = []
  for (const [filmId, zones] of byFilm) {
    const film = films.find((f) => f.id === filmId)!
    items.push(filmItem(film, zones, overrides))
  }
  for (const [vlt, zones] of byVlt) {
    items.push({
      kind: 'pelicula',
      film_id: null,
      service_type_id: null,
      glass_zones: zones,
      description: `Película com transmissão de ${vlt.toLocaleString('pt-BR')}% — ${zonesText(zones)}`,
      quantity: '1',
      unit_price: '',
      discount: '',
    })
  }
  return items
}
