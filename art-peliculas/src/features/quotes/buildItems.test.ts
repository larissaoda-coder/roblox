import { describe, expect, it } from 'vitest'
import type { Film } from '@/types/domain'
import { itemsFromSimulation, suggestedQuantity } from './buildItems'

const film = (over: Partial<Film>): Film => ({
  id: 'f1',
  name: 'G20',
  manufacturer: 'Marca',
  product_line: '',
  vlt_percent: 20,
  finish: 'neutra',
  description: '',
  uv_rejection_percent: null,
  ir_rejection_percent: null,
  tser_percent: null,
  warranty_years: null,
  technical_specs: [],
  price: 300,
  price_unit: 'veiculo',
  active: true,
  created_at: '',
  updated_at: '',
  ...over,
})

describe('itens a partir da simulação', () => {
  it('agrupa zonas pela mesma película e usa preço específico do veículo', () => {
    const f = film({})
    const items = itemsFromSimulation(
      { dianteiros: { vlt: 20, film_id: 'f1' }, traseiros: { vlt: 20, film_id: 'f1' }, para_brisa: { vlt: 70, film_id: null } },
      [f],
      new Map([['f1', 250]]),
    )
    expect(items).toHaveLength(2)
    expect(items[0].film_id).toBe('f1')
    expect(items[0].glass_zones).toEqual(['dianteiros', 'traseiros'])
    expect(items[0].unit_price).toBe('250')
    expect(items[1].film_id).toBeNull()
    expect(items[1].description).toContain('70%')
  })
  it('quantidade por vidro soma os vidros das zonas', () => {
    expect(suggestedQuantity({ price_unit: 'vidro' }, ['dianteiros', 'vidro_traseiro'])).toBe(3)
    expect(suggestedQuantity({ price_unit: 'veiculo' }, ['dianteiros', 'traseiros'])).toBe(1)
  })
})
