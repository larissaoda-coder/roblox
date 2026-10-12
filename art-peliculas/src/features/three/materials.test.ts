import { describe, expect, it } from 'vitest'
import * as THREE from 'three'
import { applyTint, prepareScene, suggestZone } from './materials'
import { buildReferenceCar, REFERENCE_GLASS } from './referenceCar'
import type { GlassMap } from '@/types/domain'

function setup() {
  const root = buildReferenceCar('hatch')
  const meshes = prepareScene(root)
  const map: GlassMap = {}
  for (const m of meshes) if (REFERENCE_GLASS[m.mesh.name]) map[m.key] = REFERENCE_GLASS[m.mesh.name]
  return { meshes, map }
}

describe('materiais dos vidros', () => {
  it('mapeia todas as zonas do modelo de referência', () => {
    const { map } = setup()
    expect(new Set(Object.values(map))).toEqual(new Set(['para_brisa', 'dianteiros', 'traseiros', 'vidro_traseiro']))
    expect(Object.keys(map)).toHaveLength(6)
  })

  it('escurece somente os vidros mapeados e restaura o original', () => {
    const { meshes, map } = setup()
    const glass = meshes.find((m) => m.mesh.name === 'para_brisa')!
    const body = meshes.find((m) => m.mesh.name === 'carroceria')!
    const glassMat = glass.mesh.material as THREE.MeshStandardMaterial
    const bodyMat = body.mesh.material as THREE.MeshPhysicalMaterial
    const before = { opacity: glassMat.opacity, color: glassMat.color.getHex(), body: bodyMat.color.getHex() }

    applyTint(meshes, map, { para_brisa: { opacity: 0.8, finish: 'neutra' } })
    expect(glassMat.opacity).toBeGreaterThan(before.opacity + 0.4)
    expect(glassMat.color.getHex()).not.toBe(before.color)
    expect(bodyMat.color.getHex()).toBe(before.body)
    const side = meshes.find((m) => m.mesh.name === 'dianteiro_esquerdo')!.mesh.material as THREE.MeshStandardMaterial
    expect(side.opacity).toBeCloseTo(before.opacity)

    applyTint(meshes, map, null)
    expect(glassMat.opacity).toBeCloseTo(before.opacity)
    expect(glassMat.color.getHex()).toBe(before.color)
  })

  it('materiais compartilhados no arquivo são isolados por malha', () => {
    const shared = new THREE.MeshStandardMaterial({ transparent: true, opacity: 0.3, name: 'Glass' })
    const root = new THREE.Group()
    const a = new THREE.Mesh(new THREE.PlaneGeometry(), shared)
    const b = new THREE.Mesh(new THREE.PlaneGeometry(), shared)
    a.name = 'front_door_glass_L'
    b.name = 'rear_door_glass_L'
    root.add(a, b)
    const meshes = prepareScene(root)
    applyTint(meshes, { [meshes[0].key]: 'dianteiros' }, { dianteiros: { opacity: 0.9, finish: 'neutra' } })
    expect((a.material as THREE.Material).opacity).toBeGreaterThan(0.8)
    expect((b.material as THREE.Material).opacity).toBeCloseTo(0.3)
  })

  it('sugere zonas pelo nome da malha', () => {
    expect(suggestZone({ name: 'Windshield', materialName: '' })).toBe('para_brisa')
    expect(suggestZone({ name: 'rear_window', materialName: 'glass' })).toBe('vidro_traseiro')
    expect(suggestZone({ name: 'door_front_left_glass', materialName: '' })).toBe('dianteiros')
    expect(suggestZone({ name: 'door_rear_right_glass', materialName: '' })).toBe('traseiros')
    expect(suggestZone({ name: 'body', materialName: 'paint' })).toBeNull()
  })
})
