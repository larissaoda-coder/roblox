import * as THREE from 'three'
import type { FilmFinish, GlassMap, GlassZone } from '@/types/domain'

export interface ZoneVisual {
  /** Opacidade da película (0 = sem película, ~0.94 = muito escura). */
  opacity: number
  finish: FilmFinish
}
export type TintVisual = Partial<Record<GlassZone, ZoneVisual>>

export interface MeshInfo {
  key: string
  name: string
  materialName: string
  glassLike: boolean
  mesh: THREE.Mesh
}

interface OriginalMaterialState {
  color: THREE.Color | null
  opacity: number
  transparent: boolean
  metalness: number | null
  roughness: number | null
  transmission: number | null
  emissive: THREE.Color | null
  depthWrite: boolean
}

const GLASS_NAME = /glass|vidro|window|windshield|windscreen|janela|glas|vitre|cristal|parabrisa|para-brisa/i
const TINT_COLOR = new THREE.Color('#0a0a0a')
const MIRROR_COLOR = new THREE.Color('#3a3a3a')
const SELECT_EMISSIVE = new THREE.Color('#5a5a5a')

type AnyMaterial = THREE.Material & {
  color?: THREE.Color
  metalness?: number
  roughness?: number
  transmission?: number
  emissive?: THREE.Color
}

function snapshot(m: AnyMaterial): OriginalMaterialState {
  return {
    color: m.color ? m.color.clone() : null,
    opacity: m.opacity,
    transparent: m.transparent,
    metalness: typeof m.metalness === 'number' ? m.metalness : null,
    roughness: typeof m.roughness === 'number' ? m.roughness : null,
    transmission: typeof m.transmission === 'number' ? m.transmission : null,
    emissive: m.emissive ? m.emissive.clone() : null,
    depthWrite: m.depthWrite,
  }
}

function isGlassMaterial(m: AnyMaterial) {
  return m.transparent || m.opacity < 0.99 || (typeof m.transmission === 'number' && m.transmission > 0) || GLASS_NAME.test(m.name ?? '')
}

/**
 * Prepara a cena: clona os materiais por malha (para tingir cada vidro de forma independente),
 * guarda o estado original e gera uma chave estável por malha (nome + ordem no arquivo).
 */
export function prepareScene(root: THREE.Object3D): MeshInfo[] {
  const meshes: MeshInfo[] = []
  let index = 0
  root.traverse((obj) => {
    const mesh = obj as THREE.Mesh
    if (!mesh.isMesh) return
    const key = `${mesh.name || 'malha'}#${index++}`
    const mats = (Array.isArray(mesh.material) ? mesh.material : [mesh.material]) as AnyMaterial[]
    const cloned = mats.map((m) => {
      const c = m.clone() as AnyMaterial
      c.userData.original = snapshot(m)
      return c
    })
    mesh.material = Array.isArray(mesh.material) ? cloned : cloned[0]
    mesh.castShadow = true
    mesh.receiveShadow = true
    mesh.userData.meshKey = key
    const materialName = mats.map((m) => m.name).filter(Boolean).join(', ')
    meshes.push({
      key,
      name: mesh.name || '(sem nome)',
      materialName,
      glassLike: GLASS_NAME.test(mesh.name) || mats.some(isGlassMaterial),
      mesh,
    })
  })
  return meshes
}

function restore(m: AnyMaterial) {
  const o = m.userData.original as OriginalMaterialState | undefined
  if (!o) return
  if (o.color && m.color) m.color.copy(o.color)
  m.opacity = o.opacity
  m.transparent = o.transparent
  m.depthWrite = o.depthWrite
  if (o.metalness !== null) m.metalness = o.metalness
  if (o.roughness !== null) m.roughness = o.roughness
  if (o.transmission !== null) m.transmission = o.transmission
  if (o.emissive && m.emissive) m.emissive.copy(o.emissive)
}

function tint(m: AnyMaterial, visual: ZoneVisual) {
  const o = m.userData.original as OriginalMaterialState
  const k = Math.min(1, visual.opacity / 0.94)
  const target = visual.finish === 'refletiva' ? MIRROR_COLOR : TINT_COLOR
  if (m.color && o.color) m.color.copy(o.color).lerp(target, Math.min(1, 0.25 + k * 0.75))
  m.transparent = true
  m.depthWrite = false
  const base = o.transparent || o.opacity < 1 ? o.opacity : 0.25
  m.opacity = base + (Math.max(base, 0.96) - base) * k
  if (o.transmission !== null) m.transmission = o.transmission * (1 - k * 0.92)
  if (visual.finish === 'refletiva') {
    if (o.metalness !== null) m.metalness = Math.max(o.metalness, 0.55 * k + (o.metalness ?? 0) * (1 - k))
    if (o.roughness !== null) m.roughness = Math.min(o.roughness, 0.12)
  }
  m.needsUpdate = true
}

/** Aplica (ou remove, quando `visual` é null) as películas nas malhas mapeadas. */
export function applyTint(meshes: MeshInfo[], glassMap: GlassMap, visual: TintVisual | null, selectedKey?: string | null) {
  for (const info of meshes) {
    const zone = glassMap[info.key]
    const zoneVisual = zone && visual ? visual[zone] : undefined
    const mats = (Array.isArray(info.mesh.material) ? info.mesh.material : [info.mesh.material]) as AnyMaterial[]
    for (const m of mats) {
      restore(m)
      if (zoneVisual && zoneVisual.opacity > 0.001) tint(m, zoneVisual)
      if (selectedKey && info.key === selectedKey && m.emissive) m.emissive.copy(SELECT_EMISSIVE)
    }
  }
}

const SUGGESTIONS: Array<[RegExp, GlassZone]> = [
  [/wind(shield|screen)|front[\s_.-]*glass|para[\s_.-]*brisa|parabrisa/i, 'para_brisa'],
  [/(rear|back)[\s_.-]*(window|glass|screen|windshield)|vigia|traseiro[\s_.-]*principal|tailgate[\s_.-]*glass/i, 'vidro_traseiro'],
  [/(front|dianteir)[\s\S]*(door|window|side|janela|vidro)|(door|window|janela|vidro)[\s\S]*(front|dianteir)|\bf[lr]\b|_f[lr]_/i, 'dianteiros'],
  [/(rear|back|traseir)[\s\S]*(door|window|side|janela|vidro)|(door|window|janela|vidro)[\s\S]*(rear|back|traseir)|\br[lr]\b|_r[lr]_|quarter/i, 'traseiros'],
]

/** Sugere a zona de um vidro a partir do nome da malha/material (pode ser ajustado pelo administrador). */
export function suggestZone(info: Pick<MeshInfo, 'name' | 'materialName'>): GlassZone | null {
  const text = `${info.name} ${info.materialName}`
  for (const [re, zone] of SUGGESTIONS) if (re.test(text)) return zone
  return null
}
