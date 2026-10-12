import { createContext, Suspense, useContext, useEffect, useRef, type MutableRefObject, type ReactNode } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Bounds, ContactShadows, Environment, Html, Lightformer, OrbitControls } from '@react-three/drei'
import { Spinner } from '@/components/ui'

function LoadingModel() {
  return (
    <Html center>
      <div className="flex items-center gap-2 whitespace-nowrap rounded-md bg-white/90 px-3 py-2 text-sm text-neutral-600 shadow-soft">
        <Spinner className="h-4 w-4" /> Carregando modelo 3D…
      </div>
    </Html>
  )
}

type ApplyFn = (tinted: boolean) => void

interface StageContextValue {
  applyRef: MutableRefObject<ApplyFn | null>
  compare: boolean
}

const StageContext = createContext<StageContextValue | null>(null)

/**
 * Registra a função que alterna entre o vidro original e o vidro com película.
 * Fora do modo comparação, a película é aplicada sempre que as dependências mudam.
 */
export function useTintRegistration(apply: ApplyFn) {
  const ctx = useContext(StageContext)
  useEffect(() => {
    if (!ctx) return
    ctx.applyRef.current = apply
    if (!ctx.compare) apply(true)
    return () => {
      if (ctx.applyRef.current === apply) ctx.applyRef.current = null
    }
  }, [ctx, apply])
}

/** Renderiza a cena duas vezes: original à esquerda e simulação à direita da divisória. */
function SplitRenderer({ splitRef, applyRef }: { splitRef: MutableRefObject<number>; applyRef: MutableRefObject<ApplyFn | null> }) {
  useFrame(({ gl, scene, camera, size }) => {
    const x = Math.round(size.width * splitRef.current)
    const apply = applyRef.current
    gl.autoClear = false
    gl.setViewport(0, 0, size.width, size.height)
    gl.setScissorTest(true)
    apply?.(false)
    gl.setScissor(0, 0, x, size.height)
    gl.clear()
    gl.render(scene, camera)
    apply?.(true)
    gl.setScissor(x, 0, size.width - x, size.height)
    gl.clear()
    gl.render(scene, camera)
    gl.setScissorTest(false)
    gl.autoClear = true
  }, 1)
  return null
}

export function Stage({
  children,
  compare = false,
  splitRef,
  autoRotate = false,
  className,
  fitKey,
}: {
  children: ReactNode
  compare?: boolean
  splitRef?: MutableRefObject<number>
  autoRotate?: boolean
  className?: string
  /** Quando muda, reenquadra a câmera. */
  fitKey?: string
}) {
  const applyRef = useRef<ApplyFn | null>(null)
  const fallbackSplit = useRef(0.5)

  return (
    <div className={className}>
      <Suspense
        fallback={
          <div className="flex h-full w-full items-center justify-center gap-2 text-sm text-neutral-500">
            <Spinner className="h-4 w-4" /> Carregando modelo 3D…
          </div>
        }
      >
        <Canvas
          shadows
          dpr={[1, 2]}
          camera={{ position: [5.2, 2.1, 5.8], fov: 32, near: 0.1, far: 200 }}
          gl={{ antialias: true, preserveDrawingBuffer: true }}
        >
          <StageContext.Provider value={{ applyRef, compare }}>
            <color attach="background" args={['#f4f4f4']} />
            <ambientLight intensity={0.55} />
            <directionalLight position={[5, 8, 4]} intensity={1.6} castShadow shadow-mapSize={[1024, 1024]} />
            <directionalLight position={[-6, 4, -3]} intensity={0.5} />
            <Environment resolution={256}>
              <Lightformer form="rect" intensity={2.2} position={[0, 5, 0]} rotation-x={Math.PI / 2} scale={[10, 10, 1]} />
              <Lightformer form="rect" intensity={1.4} position={[-6, 2, 1]} rotation-y={Math.PI / 2} scale={[10, 3, 1]} />
              <Lightformer form="rect" intensity={1.4} position={[6, 2, -1]} rotation-y={-Math.PI / 2} scale={[10, 3, 1]} />
              <Lightformer form="ring" color="#ffffff" intensity={1} position={[0, 3, 8]} scale={4} />
            </Environment>
            <Suspense fallback={<LoadingModel />}>
              <Bounds key={fitKey} fit clip observe margin={1.0} maxDuration={0.6}>
                {children}
              </Bounds>
            </Suspense>
            <ContactShadows position={[0, 0.001, 0]} opacity={0.42} scale={14} blur={2.4} far={4} resolution={512} color="#000000" />
            <OrbitControls makeDefault enablePan={false} minDistance={2.5} maxDistance={18} maxPolarAngle={Math.PI / 2.05} autoRotate={autoRotate} autoRotateSpeed={0.6} />
            {compare && <SplitRenderer splitRef={splitRef ?? fallbackSplit} applyRef={applyRef} />}
          </StageContext.Provider>
        </Canvas>
      </Suspense>
    </div>
  )
}
