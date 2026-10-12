import * as THREE from 'three'
import type { GlassZone, VehicleCategory } from '@/types/domain'

/**
 * Modelo GENÉRICO de referência, gerado proceduralmente por categoria.
 * Usado no simulador apenas quando o veículo não possui imagem com máscaras nem modelo 3D,
 * sempre identificado na interface como ilustração genérica — não representa o modelo real.
 */

export type ReferenceKind = 'hatch' | 'sedan' | 'suv' | 'picape'

export function referenceKindFor(category: VehicleCategory): ReferenceKind {
  if (category === 'sedan' || category === 'cupe') return 'sedan'
  if (category === 'suv' || category === 'minivan' || category === 'utilitario') return 'suv'
  if (category === 'picape') return 'picape'
  return 'hatch'
}

export const REFERENCE_LABELS: Record<ReferenceKind, string> = {
  hatch: 'hatch',
  sedan: 'sedã',
  suv: 'SUV',
  picape: 'picape',
}

interface Profile {
  length: number
  bodyHW: number
  cabinHW: number
  ground: number
  wheelR: number
  rearAxle: number
  frontAxle: number
  belt: number
  roof: number
  rb: number
  rr: number
  fr: number
  fb: number
  bPillar: number
  hoodY: number
  noseY: number
  tailY: number
}

const PROFILES: Record<ReferenceKind, Profile> = {
  hatch: { length: 4.05, bodyHW: 0.87, cabinHW: 0.78, ground: 0.3, wheelR: 0.31, rearAxle: 0.72, frontAxle: 3.22, belt: 0.93, roof: 1.47, rb: 0.12, rr: 0.48, fr: 2.12, fb: 2.95, bPillar: 1.56, hoodY: 0.8, noseY: 0.62, tailY: 0.96 },
  sedan: { length: 4.5, bodyHW: 0.88, cabinHW: 0.79, ground: 0.29, wheelR: 0.31, rearAxle: 0.98, frontAxle: 3.6, belt: 0.95, roof: 1.45, rb: 0.98, rr: 1.58, fr: 2.6, fb: 3.33, bPillar: 2.1, hoodY: 0.81, noseY: 0.62, tailY: 0.99 },
  suv: { length: 4.35, bodyHW: 0.91, cabinHW: 0.82, ground: 0.4, wheelR: 0.36, rearAxle: 0.82, frontAxle: 3.4, belt: 1.1, roof: 1.67, rb: 0.12, rr: 0.32, fr: 2.28, fb: 3.06, bPillar: 1.72, hoodY: 0.99, noseY: 0.8, tailY: 1.12 },
  picape: { length: 5.25, bodyHW: 0.92, cabinHW: 0.83, ground: 0.45, wheelR: 0.38, rearAxle: 1.05, frontAxle: 4.18, belt: 1.15, roof: 1.82, rb: 1.86, rr: 1.94, fr: 3.36, fb: 4.08, bPillar: 2.68, hoodY: 1.09, noseY: 0.93, tailY: 1.15 },
}

type V2 = [number, number]

function bodyShape(p: Profile) {
  const s = new THREE.Shape()
  const ra = p.wheelR + 0.06
  const arch = (cx: number) => {
    const pts: V2[] = []
    for (let i = 0; i <= 18; i++) {
      const t = Math.PI - (i / 18) * Math.PI
      pts.push([cx + ra * Math.cos(t), p.wheelR + ra * Math.sin(t)])
    }
    return pts
  }
  s.moveTo(0.06, p.ground)
  s.lineTo(p.rearAxle - ra, p.ground)
  arch(p.rearAxle).forEach(([x, y]) => s.lineTo(x, Math.max(y, p.ground)))
  s.lineTo(p.frontAxle - ra, p.ground)
  arch(p.frontAxle).forEach(([x, y]) => s.lineTo(x, Math.max(y, p.ground)))
  s.lineTo(p.length - 0.1, p.ground)
  s.quadraticCurveTo(p.length, p.ground + 0.02, p.length, p.ground + 0.14)
  s.lineTo(p.length - 0.01, p.noseY - 0.04)
  s.quadraticCurveTo(p.length - 0.02, p.hoodY - 0.02, p.length - 0.2, p.hoodY)
  s.quadraticCurveTo((p.length + p.fb) / 2, p.hoodY + 0.08, p.fb + 0.04, p.belt)
  if (p.tailY > p.belt + 0.01) {
    // sedã: tampa do porta-malas um pouco acima da linha de cintura
    s.lineTo(p.rb - 0.06, p.belt)
    s.quadraticCurveTo(p.rb - 0.4, p.tailY, 0.22, p.tailY)
  } else {
    s.lineTo(0.2, p.belt)
  }
  s.quadraticCurveTo(0.02, p.tailY, 0, p.tailY - 0.12)
  s.lineTo(0, p.ground + 0.14)
  s.quadraticCurveTo(0, p.ground, 0.06, p.ground)
  return s
}

/** Interseção de duas retas dadas por ponto + direção. */
function intersect(a: V2, da: V2, b: V2, db: V2): V2 {
  const det = da[0] * db[1] - da[1] * db[0]
  const t = ((b[0] - a[0]) * db[1] - (b[1] - a[1]) * db[0]) / det
  return [a[0] + da[0] * t, a[1] + da[1] * t]
}

/** Abertura das janelas (trapézio da cabine recuado pela espessura das colunas). */
function daylight(p: Profile, pillar = 0.07): V2[] {
  const bottom = p.belt + 0.035
  const top = p.roof - 0.06
  const rearDir: V2 = [p.rr - p.rb, p.roof - p.belt]
  const frontDir: V2 = [p.fr - p.fb, p.roof - p.belt]
  const rearLen = Math.hypot(...rearDir)
  const frontLen = Math.hypot(...frontDir)
  // normais apontando para dentro da cabine
  const rearN: V2 = [rearDir[1] / rearLen, -rearDir[0] / rearLen]
  const frontN: V2 = [-frontDir[1] / frontLen, frontDir[0] / frontLen]
  const rearP: V2 = [p.rb + rearN[0] * pillar, p.belt + rearN[1] * pillar]
  const frontP: V2 = [p.fb + frontN[0] * pillar, p.belt + frontN[1] * pillar]
  return [
    intersect(rearP, rearDir, [0, bottom], [1, 0]),
    intersect(frontP, frontDir, [0, bottom], [1, 0]),
    intersect(frontP, frontDir, [0, top], [1, 0]),
    intersect(rearP, rearDir, [0, top], [1, 0]),
  ]
}

/** Recorta um polígono convexo ao intervalo [xmin, xmax]. */
function clipX(poly: V2[], xmin: number, xmax: number): V2[] {
  const clip = (pts: V2[], inside: (p: V2) => boolean, edgeX: number) => {
    const out: V2[] = []
    for (let i = 0; i < pts.length; i++) {
      const cur = pts[i]
      const prev = pts[(i + pts.length - 1) % pts.length]
      const cin = inside(cur)
      const pin = inside(prev)
      if (cin !== pin) {
        const t = (edgeX - prev[0]) / (cur[0] - prev[0])
        out.push([edgeX, prev[1] + (cur[1] - prev[1]) * t])
      }
      if (cin) out.push(cur)
    }
    return out
  }
  return clip(clip(poly, (p) => p[0] >= xmin, xmin), (p) => p[0] <= xmax, xmax)
}

function shapeFrom(points: V2[]) {
  const s = new THREE.Shape()
  points.forEach(([x, y], i) => (i === 0 ? s.moveTo(x, y) : s.lineTo(x, y)))
  s.closePath()
  return s
}

function quad(a: THREE.Vector3, b: THREE.Vector3, c: THREE.Vector3, d: THREE.Vector3) {
  const g = new THREE.BufferGeometry()
  g.setAttribute('position', new THREE.Float32BufferAttribute([...a.toArray(), ...b.toArray(), ...c.toArray(), ...a.toArray(), ...c.toArray(), ...d.toArray()], 3))
  g.computeVertexNormals()
  return g
}

export const REFERENCE_GLASS: Record<string, GlassZone> = {
  para_brisa: 'para_brisa',
  vidro_traseiro: 'vidro_traseiro',
  dianteiro_esquerdo: 'dianteiros',
  dianteiro_direito: 'dianteiros',
  traseiro_esquerdo: 'traseiros',
  traseiro_direito: 'traseiros',
}

export function buildReferenceCar(kind: ReferenceKind) {
  const p = PROFILES[kind]
  const group = new THREE.Group()
  group.name = `referencia_${kind}`

  const body = new THREE.MeshPhysicalMaterial({ name: 'carroceria', color: '#e6e6e6', metalness: 0.3, roughness: 0.33, clearcoat: 1, clearcoatRoughness: 0.07 })
  const trim = new THREE.MeshStandardMaterial({ name: 'acabamento', color: '#161616', roughness: 0.55, metalness: 0.1, side: THREE.DoubleSide })
  const frame = new THREE.MeshPhysicalMaterial({ name: 'carroceria_coluna', color: '#e6e6e6', metalness: 0.3, roughness: 0.33, clearcoat: 1, side: THREE.DoubleSide })
  const glass = new THREE.MeshStandardMaterial({
    name: 'vidro',
    color: '#ececec',
    transparent: true,
    opacity: 0.2,
    roughness: 0.04,
    metalness: 0.05,
    envMapIntensity: 1.6,
    side: THREE.DoubleSide,
    depthWrite: false,
  })
  const interior = new THREE.MeshStandardMaterial({ name: 'interior', color: '#5e5e5e', roughness: 0.9, side: THREE.BackSide })
  const seat = new THREE.MeshStandardMaterial({ name: 'bancos', color: '#767676', roughness: 0.85 })
  const tire = new THREE.MeshStandardMaterial({ name: 'pneu', color: '#1b1b1b', roughness: 0.9 })
  const rim = new THREE.MeshStandardMaterial({ name: 'roda', color: '#c8c8c8', metalness: 0.85, roughness: 0.25 })
  const lamp = new THREE.MeshStandardMaterial({ name: 'farol', color: '#f2f2f2', emissive: '#7a7a7a', roughness: 0.15, metalness: 0.4 })
  const tail = new THREE.MeshStandardMaterial({ name: 'lanterna', color: '#2c2c2c', roughness: 0.2, metalness: 0.3 })

  // Carroceria inferior (perfil lateral extrudado com cantos arredondados)
  const bevel = 0.06
  const depth = p.bodyHW * 2 - bevel * 2
  const bodyGeo = new THREE.ExtrudeGeometry(bodyShape(p), { depth, bevelEnabled: true, bevelThickness: bevel, bevelSize: 0.045, bevelSegments: 5, curveSegments: 28 })
  bodyGeo.translate(0, 0, -depth / 2)
  const bodyMesh = new THREE.Mesh(bodyGeo, body)
  bodyMesh.name = 'carroceria'
  group.add(bodyMesh)

  // Teto
  const roofShape = shapeFrom([
    [p.rr - 0.04, p.roof - 0.035],
    [p.fr + 0.04, p.roof - 0.035],
    [p.fr - 0.06, p.roof + 0.035],
    [p.rr + 0.08, p.roof + 0.035],
  ])
  const roofDepth = p.cabinHW * 2 - 0.06
  const roofGeo = new THREE.ExtrudeGeometry(roofShape, { depth: roofDepth, bevelEnabled: true, bevelThickness: 0.03, bevelSize: 0.02, bevelSegments: 3 })
  roofGeo.translate(0, 0, -roofDepth / 2)
  const roofMesh = new THREE.Mesh(roofGeo, body)
  roofMesh.name = 'teto'
  group.add(roofMesh)

  // Laterais da cabine com aberturas e vidros laterais
  const dl = daylight(p)
  const gap = 0.055
  const rearWin = clipX(dl, -10, p.bPillar - gap)
  const frontWin = clipX(dl, p.bPillar + gap, 10)
  const cabinOutline: V2[] = [
    [p.rb, p.belt],
    [p.fb, p.belt],
    [p.fr, p.roof],
    [p.rr, p.roof],
  ]
  const sides: Array<[number, string]> = [
    [1, 'esquerdo'],
    [-1, 'direito'],
  ]
  for (const [sign, label] of sides) {
    const z = sign * p.cabinHW
    const frameShape = shapeFrom(cabinOutline)
    frameShape.holes.push(shapeFrom(rearWin), shapeFrom(frontWin))
    const frameMesh = new THREE.Mesh(new THREE.ShapeGeometry(frameShape), frame)
    frameMesh.position.z = z
    frameMesh.name = `coluna_${label}`
    group.add(frameMesh)

    const bp = new THREE.Mesh(new THREE.BoxGeometry(gap * 2, p.roof - p.belt - 0.06, 0.012), trim)
    bp.position.set(p.bPillar, (p.roof + p.belt) / 2 - 0.01, z + sign * 0.004)
    bp.name = `coluna_b_${label}`
    group.add(bp)

    for (const [poly, zoneName] of [
      [frontWin, `dianteiro_${label}`],
      [rearWin, `traseiro_${label}`],
    ] as Array<[V2[], string]>) {
      const g = new THREE.Mesh(new THREE.ShapeGeometry(shapeFrom(poly)), glass)
      g.position.z = z + sign * 0.002
      g.name = zoneName
      g.renderOrder = 2
      group.add(g)
    }
  }

  // Para-brisa e vidro traseiro, com colunas A e C
  const w = p.cabinHW - 0.07
  const ws = quad(
    new THREE.Vector3(p.fb - 0.01, p.belt + 0.02, -w),
    new THREE.Vector3(p.fb - 0.01, p.belt + 0.02, w),
    new THREE.Vector3(p.fr + 0.02, p.roof - 0.035, w),
    new THREE.Vector3(p.fr + 0.02, p.roof - 0.035, -w),
  )
  const windshield = new THREE.Mesh(ws, glass)
  windshield.name = 'para_brisa'
  windshield.renderOrder = 2
  group.add(windshield)

  const rw = quad(
    new THREE.Vector3(p.rb + 0.01, p.belt + 0.02, w),
    new THREE.Vector3(p.rb + 0.01, p.belt + 0.02, -w),
    new THREE.Vector3(p.rr - 0.02, p.roof - 0.035, -w),
    new THREE.Vector3(p.rr - 0.02, p.roof - 0.035, w),
  )
  const rear = new THREE.Mesh(rw, glass)
  rear.name = 'vidro_traseiro'
  rear.renderOrder = 2
  group.add(rear)

  for (const sign of [1, -1]) {
    const a = quad(
      new THREE.Vector3(p.fb, p.belt, sign * w),
      new THREE.Vector3(p.fb, p.belt, sign * p.cabinHW),
      new THREE.Vector3(p.fr, p.roof, sign * p.cabinHW),
      new THREE.Vector3(p.fr, p.roof, sign * w),
    )
    const c = quad(
      new THREE.Vector3(p.rb, p.belt, sign * w),
      new THREE.Vector3(p.rb, p.belt, sign * p.cabinHW),
      new THREE.Vector3(p.rr, p.roof, sign * p.cabinHW),
      new THREE.Vector3(p.rr, p.roof, sign * w),
    )
    group.add(Object.assign(new THREE.Mesh(a, frame), { name: 'coluna_a' }))
    group.add(Object.assign(new THREE.Mesh(c, frame), { name: 'coluna_c' }))
  }

  // Interior (visível através dos vidros): volume com o formato da cabine, renderizado por dentro
  const inner = daylight(p, 0.05)
  const interiorShape = shapeFrom([[inner[0][0], p.belt - 0.22], [inner[1][0], p.belt - 0.22], inner[1], inner[2], inner[3], inner[0]])
  const inDepth = p.cabinHW * 2 - 0.12
  const interiorGeo = new THREE.ExtrudeGeometry(interiorShape, { depth: inDepth, bevelEnabled: false })
  interiorGeo.translate(0, 0, -inDepth / 2)
  const inside = new THREE.Mesh(interiorGeo, interior)
  inside.name = 'interior'
  group.add(inside)
  const seatXs = [p.bPillar - 0.12, p.rb + Math.max(0.35, (p.bPillar - p.rb) * 0.35)]
  for (const sx of seatXs) {
    for (const sz of [-0.38, 0.38]) {
      const back = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.5, 0.46), seat)
      back.position.set(sx, p.belt + 0.08, sz * (p.cabinHW / 0.8))
      back.rotation.z = 0.12
      back.name = 'banco'
      group.add(back)
      const head = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.16, 0.24), seat)
      head.position.set(sx + 0.04, p.belt + 0.42, sz * (p.cabinHW / 0.8))
      head.name = 'encosto_cabeca'
      group.add(head)
    }
  }

  // Rodas
  for (const ax of [p.rearAxle, p.frontAxle]) {
    for (const sign of [1, -1]) {
      const wheel = new THREE.Group()
      const t = new THREE.Mesh(new THREE.CylinderGeometry(p.wheelR, p.wheelR, 0.24, 40), tire)
      t.rotation.x = Math.PI / 2
      const r = new THREE.Mesh(new THREE.CylinderGeometry(p.wheelR * 0.62, p.wheelR * 0.62, 0.245, 32), rim)
      r.rotation.x = Math.PI / 2
      wheel.add(t, r)
      wheel.position.set(ax, p.wheelR, sign * (p.bodyHW - 0.13))
      wheel.name = 'roda'
      group.add(wheel)
    }
  }

  // Faróis, lanternas e grade
  for (const sign of [1, -1]) {
    const h = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.07, 0.34), lamp)
    h.position.set(p.length - 0.02, p.noseY + 0.07, sign * (p.bodyHW - 0.26))
    h.name = 'farol'
    group.add(h)
    const tl = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.09, 0.3), tail)
    tl.position.set(0.0, p.tailY - 0.2, sign * (p.bodyHW - 0.24))
    tl.name = 'lanterna'
    group.add(tl)
  }
  const grille = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.12, 0.7), trim)
  grille.position.set(p.length - 0.01, p.noseY - 0.08, 0)
  grille.name = 'grade'
  group.add(grille)

  // Centraliza no eixo X e apoia no chão (y = 0)
  group.position.x = -p.length / 2
  const root = new THREE.Group()
  root.add(group)
  return root
}
