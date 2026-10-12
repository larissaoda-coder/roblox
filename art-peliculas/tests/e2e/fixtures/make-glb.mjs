// Gera um modelo .glb SINTÉTICO (caixa + vidros nomeados) usado apenas nos testes automatizados.
// Uso: node tests/e2e/fixtures/make-glb.mjs
import { writeFileSync } from 'node:fs'
import * as THREE from 'three'
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js'

// GLTFExporter usa FileReader para o modo binário; polyfill mínimo para Node.
globalThis.FileReader = class {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then((buf) => {
      this.result = buf
      this.onloadend?.()
    })
  }
  readAsDataURL(blob) {
    blob.arrayBuffer().then((buf) => {
      this.result = `data:${blob.type};base64,${Buffer.from(buf).toString('base64')}`
      this.onloadend?.()
    })
  }
}

const scene = new THREE.Scene()
const paint = new THREE.MeshStandardMaterial({ name: 'Paint', color: '#d9d9d9', metalness: 0.3, roughness: 0.4 })
const glass = new THREE.MeshStandardMaterial({ name: 'Glass', color: '#e6e6e6', transparent: true, opacity: 0.25 })

const body = new THREE.Mesh(new THREE.BoxGeometry(4.2, 0.7, 1.7), paint)
body.name = 'Body'
body.position.y = 0.65
const cabin = new THREE.Mesh(new THREE.BoxGeometry(2.2, 0.55, 1.5), paint)
cabin.name = 'Cabin'
cabin.position.set(-0.2, 1.25, 0)
scene.add(body, cabin)

const pane = (name, w, h, pos, rot) => {
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), glass)
  m.name = name
  m.position.set(...pos)
  m.rotation.set(...rot)
  scene.add(m)
}
pane('Windshield', 1.4, 0.5, [0.91, 1.25, 0], [0, Math.PI / 2, 0])
pane('Rear_Window', 1.4, 0.5, [-1.31, 1.25, 0], [0, -Math.PI / 2, 0])
pane('Window_Front_L', 0.9, 0.4, [0.35, 1.27, 0.76], [0, 0, 0])
pane('Window_Front_R', 0.9, 0.4, [0.35, 1.27, -0.76], [0, Math.PI, 0])
pane('Window_Rear_L', 0.9, 0.4, [-0.7, 1.27, 0.76], [0, 0, 0])
pane('Window_Rear_R', 0.9, 0.4, [-0.7, 1.27, -0.76], [0, Math.PI, 0])
for (const [x, z] of [[1.3, 0.85], [1.3, -0.85], [-1.3, 0.85], [-1.3, -0.85]]) {
  const wheel = new THREE.Mesh(new THREE.CylinderGeometry(0.33, 0.33, 0.22, 24), new THREE.MeshStandardMaterial({ name: 'Tire', color: '#1a1a1a' }))
  wheel.name = 'Wheel'
  wheel.rotation.x = Math.PI / 2
  wheel.position.set(x, 0.33, z)
  scene.add(wheel)
}

const glb = await new GLTFExporter().parseAsync(scene, { binary: true })
writeFileSync(new URL('./modelo-sintetico.glb', import.meta.url), Buffer.from(glb))
console.log('modelo-sintetico.glb', glb.byteLength, 'bytes')
