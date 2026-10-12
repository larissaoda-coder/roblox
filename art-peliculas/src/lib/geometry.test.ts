import { describe, expect, it } from 'vitest'
import { centroid, cleanMasks, polygonArea, toSvgPoints, zonesWithMasks } from './geometry'
import { vltToOpacity, isBelowLegal } from './tint'

describe('geometria das máscaras', () => {
  const square: [number, number][] = [
    [0, 0],
    [1, 0],
    [1, 1],
    [0, 1],
  ]
  it('centroide e área', () => {
    expect(centroid(square)).toEqual([0.5, 0.5])
    expect(polygonArea(square)).toBe(1)
  })
  it('converte para pontos SVG', () => {
    expect(toSvgPoints([[0.5, 0.25]], 200, 100)).toBe('100.00,25.00')
  })
  it('limpa polígonos degenerados e coordenadas fora do intervalo', () => {
    const cleaned = cleanMasks({
      para_brisa: [
        [
          [-0.1, 0.123456],
          [1.2, 0],
          [0.5, 0.5],
        ],
        [
          [0, 0],
          [1, 1],
        ],
      ],
      traseiros: [],
    })
    expect(cleaned).toEqual({ para_brisa: [[[0, 0.1235], [1, 0], [0.5, 0.5]]] })
    expect(zonesWithMasks(cleaned)).toEqual(['para_brisa'])
  })
})

describe('tingimento', () => {
  it('películas mais escuras produzem mais opacidade', () => {
    expect(vltToOpacity(5)).toBeGreaterThan(vltToOpacity(35))
    expect(vltToOpacity(35)).toBeGreaterThan(vltToOpacity(70))
    expect(vltToOpacity(100)).toBe(0)
    expect(vltToOpacity(0)).toBeLessThanOrEqual(0.94)
  })
  it('compara com a referência legal da zona', () => {
    const limits = { windshield: 75, front: 70, rear: 28 }
    expect(isBelowLegal('para_brisa', 70, limits)).toBe(true)
    expect(isBelowLegal('dianteiros', 70, limits)).toBe(false)
    expect(isBelowLegal('traseiros', 20, limits)).toBe(true)
    expect(isBelowLegal('vidro_traseiro', 35, limits)).toBe(false)
  })
})
