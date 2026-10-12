import { useCallback, useEffect, useMemo } from 'react'
import * as THREE from 'three'
import { useGLTF } from '@react-three/drei'
import type { ThreeEvent } from '@react-three/fiber'
import type { GlassMap } from '@/types/domain'
import { applyTint, prepareScene, type MeshInfo, type TintVisual } from './materials'
import { buildReferenceCar, REFERENCE_GLASS, type ReferenceKind } from './referenceCar'
import { useTintRegistration } from './Stage'

/** Modelo genérico de referência (procedural). */
export function ReferenceCarModel({ kind, visual }: { kind: ReferenceKind; visual: TintVisual | null }) {
  const { root, meshes, glassMap } = useMemo(() => {
    const root = buildReferenceCar(kind)
    const meshes = prepareScene(root)
    const glassMap: GlassMap = {}
    for (const m of meshes) {
      const zone = REFERENCE_GLASS[m.mesh.name]
      if (zone) glassMap[m.key] = zone
    }
    return { root, meshes, glassMap }
  }, [kind])

  useEffect(
    () => () => {
      root.traverse((o) => {
        const mesh = o as THREE.Mesh
        if (mesh.isMesh) {
          mesh.geometry.dispose()
          ;(Array.isArray(mesh.material) ? mesh.material : [mesh.material]).forEach((m) => m.dispose())
        }
      })
    },
    [root],
  )

  const apply = useCallback((tinted: boolean) => applyTint(meshes, glassMap, tinted ? visual : null), [meshes, glassMap, visual])
  useTintRegistration(apply)

  return <primitive object={root} />
}

/** Modelo 3D enviado pelo administrador (.glb), normalizado para ~4,3 m e apoiado no chão. */
export function GltfCarModel({
  url,
  glassMap,
  visual,
  selectedKey,
  onMeshes,
  onPick,
}: {
  url: string
  glassMap: GlassMap
  visual: TintVisual | null
  selectedKey?: string | null
  onMeshes?: (meshes: MeshInfo[]) => void
  onPick?: (key: string) => void
}) {
  const gltf = useGLTF(url)
  const { scene, meshes } = useMemo(() => {
    const scene = gltf.scene.clone(true)
    const box = new THREE.Box3().setFromObject(scene)
    const size = box.getSize(new THREE.Vector3())
    const scale = 4.3 / Math.max(size.x, size.z, 0.0001)
    scene.scale.setScalar(scale)
    const scaled = new THREE.Box3().setFromObject(scene)
    const center = scaled.getCenter(new THREE.Vector3())
    scene.position.set(-center.x, -scaled.min.y, -center.z)
    const wrapper = new THREE.Group()
    wrapper.add(scene)
    return { scene: wrapper, meshes: prepareScene(scene) }
  }, [gltf])

  useEffect(() => onMeshes?.(meshes), [meshes, onMeshes])

  const apply = useCallback(
    (tinted: boolean) => applyTint(meshes, glassMap, tinted ? visual : null, selectedKey),
    [meshes, glassMap, visual, selectedKey],
  )
  useTintRegistration(apply)

  const handleClick = (e: ThreeEvent<MouseEvent>) => {
    if (!onPick) return
    e.stopPropagation()
    const key = e.object.userData.meshKey as string | undefined
    if (key) onPick(key)
  }

  return <primitive object={scene} onClick={handleClick} />
}
