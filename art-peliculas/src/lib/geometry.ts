import type { GlassMasks, GlassZone, Point, Polygon } from '@/types/domain'

export function clamp01(v: number) {
  return Math.min(1, Math.max(0, v))
}

export function round4(v: number) {
  return Math.round(v * 10000) / 10000
}

/** Converte pontos normalizados em atributo "points" do SVG nas dimensões informadas. */
export function toSvgPoints(poly: Polygon, width: number, height: number) {
  return poly.map(([x, y]) => `${(x * width).toFixed(2)},${(y * height).toFixed(2)}`).join(' ')
}

/** Centroide de área (cai na média dos vértices para polígonos degenerados). */
export function centroid(poly: Polygon): Point {
  let a = 0
  let cx = 0
  let cy = 0
  for (let i = 0; i < poly.length; i++) {
    const [x0, y0] = poly[i]
    const [x1, y1] = poly[(i + 1) % poly.length]
    const f = x0 * y1 - x1 * y0
    a += f
    cx += (x0 + x1) * f
    cy += (y0 + y1) * f
  }
  if (Math.abs(a) < 1e-9) {
    const n = poly.length || 1
    return [poly.reduce((s, p) => s + p[0], 0) / n, poly.reduce((s, p) => s + p[1], 0) / n]
  }
  a *= 0.5
  return [cx / (6 * a), cy / (6 * a)]
}

export function polygonArea(poly: Polygon) {
  let a = 0
  for (let i = 0; i < poly.length; i++) {
    const [x0, y0] = poly[i]
    const [x1, y1] = poly[(i + 1) % poly.length]
    a += x0 * y1 - x1 * y0
  }
  return Math.abs(a) / 2
}

export function distance(a: Point, b: Point) {
  return Math.hypot(a[0] - b[0], a[1] - b[1])
}

/** Remove zonas vazias e arredonda coordenadas antes de salvar. */
export function cleanMasks(masks: GlassMasks): GlassMasks {
  const out: GlassMasks = {}
  for (const [zone, polys] of Object.entries(masks) as Array<[GlassZone, Polygon[] | undefined]>) {
    const valid = (polys ?? []).filter((p) => p.length >= 3).map((p) => p.map(([x, y]) => [round4(clamp01(x)), round4(clamp01(y))] as Point))
    if (valid.length) out[zone] = valid
  }
  return out
}

export function zonesWithMasks(masks: GlassMasks | null | undefined): GlassZone[] {
  return (Object.keys(masks ?? {}) as GlassZone[]).filter((z) => (masks?.[z]?.length ?? 0) > 0)
}
