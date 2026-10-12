import { useEffect, useMemo, useRef, useState, type MutableRefObject } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, Box, Car, Columns2, FileText, ImageIcon, Info, RotateCcw, Save, SunDim } from 'lucide-react'
import { Badge, Button, Card, CardBody, Combobox, EmptyState, FormSuccess, PageLoader, Segmented, Skeleton, useToast } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { CATEGORY_LABELS, VIEW_LABELS, ZONES } from '@/lib/constants'
import { supabase } from '@/lib/supabase'
import { vehicleName, vehicleYears } from '@/lib/format'
import { zonesWithMasks } from '@/lib/geometry'
import { useSignedUrl } from '@/lib/storage'
import type { GlassZone, Simulation, SimulationMode, VehicleImage, VehicleWithMedia } from '@/types/domain'
import { ErrorState } from '@/features/shared/ErrorState'
import { ErrorBoundary } from '@/features/shared/ErrorBoundary'
import { useFilms } from '@/features/films/api'
import { useSettings, legalLimitsFrom } from '@/features/settings/api'
import { hasMasks, useVehicleFilms, useVehicles } from '@/features/vehicles/api'
import { Stage } from '@/features/three/Stage'
import { GltfCarModel, ReferenceCarModel } from '@/features/three/CarModels'
import { REFERENCE_LABELS, referenceKindFor } from '@/features/three/referenceCar'
import { CompareHandle } from './CompareHandle'
import { ImageTintView } from './ImageTintView'
import { FilmSelect, ZoneControls } from './ZoneControls'
import { SaveSimulationModal } from './SaveSimulationModal'
import { configToState, EMPTY_STATE, hasAnyTint, stateToConfig, stateToVisual, type TintState } from './state'

type SourceKey = string // 'ref' | '3d' | `img:${id}`

function sourcesFor(v: VehicleWithMedia) {
  const images = v.vehicle_images.filter(hasMasks).sort((a, b) => Number(b.is_primary) - Number(a.is_primary))
  const list: Array<{ key: SourceKey; label: string; mode: SimulationMode; image?: VehicleImage }> = images.map((img) => ({
    key: `img:${img.id}`,
    label: `Foto · ${VIEW_LABELS[img.view]}`,
    mode: 'imagem',
    image: img,
  }))
  if (v.model_3d_path) list.push({ key: '3d', label: 'Modelo 3D', mode: 'modelo_3d' })
  list.push({ key: 'ref', label: 'Referência genérica', mode: 'referencia' })
  return list
}

export function SimulatorPage() {
  const [params, setParams] = useSearchParams()
  const navigate = useNavigate()
  const { can } = useAuth()
  const toast = useToast()
  const vehicles = useVehicles()
  const films = useFilms()
  const settings = useSettings()
  const vehicleId = params.get('veiculo')
  const simulationId = params.get('simulacao')
  const customerParam = params.get('cliente')

  const [state, setState] = useState<TintState>(EMPTY_STATE)
  const [sourceKey, setSourceKey] = useState<SourceKey | null>(null)
  const [compare, setCompare] = useState(false)
  const [split, setSplit] = useState(0.5)
  const splitRef = useRef(0.5)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState<Simulation | null>(null)

  const activeFilms = useMemo(() => (films.data ?? []).filter((f) => f.active), [films.data])
  const vehicle = useMemo(() => vehicles.data?.find((v) => v.id === vehicleId) ?? null, [vehicles.data, vehicleId])
  const vehicleFilms = useVehicleFilms(vehicle?.id)
  const recommendedIds = useMemo(() => new Set((vehicleFilms.data ?? []).map((r) => r.film_id)), [vehicleFilms.data])
  const sources = useMemo(() => (vehicle ? sourcesFor(vehicle) : []), [vehicle])
  const source = sources.find((s) => s.key === sourceKey) ?? sources[0] ?? null
  const limits = legalLimitsFrom(settings.data)

  // Abre uma simulação salva (?simulacao=)
  const savedSim = useQuery({
    queryKey: ['simulations', 'detail', simulationId],
    enabled: Boolean(simulationId),
    queryFn: async () => {
      const { data, error } = await supabase.from('simulations').select('*').eq('id', simulationId!).maybeSingle()
      if (error) throw error
      return data as Simulation | null
    },
  })
  const loadedSim = useRef<string | null>(null)
  useEffect(() => {
    const sim = savedSim.data
    if (!sim || !films.data || loadedSim.current === sim.id) return
    loadedSim.current = sim.id
    setState(configToState(sim.config, films.data))
    setSourceKey(sim.mode === 'imagem' && sim.vehicle_image_id ? `img:${sim.vehicle_image_id}` : sim.mode === 'modelo_3d' ? '3d' : 'ref')
    if (sim.vehicle_id !== vehicleId) {
      const next = new URLSearchParams(params)
      next.set('veiculo', sim.vehicle_id)
      setParams(next, { replace: true })
    }
  }, [savedSim.data, films.data, vehicleId, params, setParams])

  // Ao trocar de veículo, volta para a melhor mídia disponível.
  const lastVehicle = useRef<string | null>(null)
  useEffect(() => {
    if (vehicle && lastVehicle.current !== vehicle.id) {
      if (lastVehicle.current !== null) setSourceKey(null)
      lastVehicle.current = vehicle.id
      setSaved(null)
    }
  }, [vehicle])

  const visual = useMemo(() => stateToVisual(state, activeFilms.length ? activeFilms : (films.data ?? [])), [state, activeFilms, films.data])

  const hiddenZones = useMemo(() => {
    if (source?.mode !== 'imagem' || !source.image) return new Set<GlassZone>()
    const present = new Set(zonesWithMasks(source.image.glass_masks))
    return new Set(ZONES.filter((z) => !present.has(z)))
  }, [source])

  const selectVehicle = (id: string | null) => {
    const next = new URLSearchParams(params)
    if (id) next.set('veiculo', id)
    else next.delete('veiculo')
    next.delete('simulacao')
    setParams(next, { replace: true })
  }

  const vehicleOptions = useMemo(
    () =>
      (vehicles.data ?? [])
        .filter((v) => v.active)
        .map((v) => {
          const media = [v.vehicle_images.some(hasMasks) ? 'foto' : null, v.model_3d_path ? '3D' : null].filter(Boolean).join(' + ')
          return {
            value: v.id,
            label: vehicleName(v),
            description: [CATEGORY_LABELS[v.category], vehicleYears(v), media ? `com ${media}` : 'sem mídia (referência genérica)'].filter(Boolean).join(' · '),
            keywords: `${v.brand} ${v.model}`,
          }
        }),
    [vehicles.data],
  )

  const applyAll = (value: string) => {
    if (!value) return setState(EMPTY_STATE)
    const next = { ...state }
    for (const z of ZONES) {
      if (value === 'custom') next[z] = { kind: 'custom', vlt: 35 }
      else {
        const film = activeFilms.find((f) => f.id === value)
        if (film) next[z] = { kind: 'film', filmId: film.id, vlt: film.vlt_percent }
      }
    }
    setState(next)
  }

  const setSplitBoth = (v: number) => {
    setSplit(v)
    splitRef.current = v
  }

  if (vehicles.isLoading || films.isLoading) return <PageLoader />
  if (vehicles.error) return <ErrorState error={vehicles.error} onRetry={() => void vehicles.refetch()} />

  return (
    <>
      <PageHeader
        title="Simulador de insulfilm"
        description="Selecione o veículo, escolha a película de cada vidro e compare com o original."
        actions={
          vehicle && (
            <Link to={`/app/garagem/${vehicle.id}`} className="text-[13px] font-medium text-neutral-600 underline-offset-4 hover:text-neutral-950 hover:underline">
              Ver na garagem
            </Link>
          )
        }
      />

      <div className="mb-5 max-w-xl">
        <Combobox
          value={vehicleId}
          onChange={(v) => selectVehicle(v)}
          options={vehicleOptions}
          placeholder="Buscar veículo por marca, modelo ou geração…"
          emptyText="Nenhum veículo encontrado na garagem."
          aria-describedby="vehicle-hint"
        />
        <p id="vehicle-hint" className="sr-only">
          Selecione o veículo a simular
        </p>
      </div>

      {!vehicle ? (
        <Card>
          <EmptyState
            icon={Car}
            title="Selecione um veículo para começar"
            description="Veículos com imagens mapeadas ou modelo 3D mostram a simulação real; os demais usam um modelo genérico de referência, identificado como tal."
          />
        </Card>
      ) : (
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
          <div className="min-w-0 space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <Segmented
                ariaLabel="Mídia do veículo"
                size="sm"
                value={source?.key ?? 'ref'}
                onChange={(k) => setSourceKey(k)}
                items={sources.map((s) => ({ value: s.key, label: s.label }))}
                className="max-w-full flex-wrap"
              />
              <div className="flex items-center gap-1.5">
                <Button size="sm" variant={compare ? 'primary' : 'secondary'} icon={<Columns2 className="h-3.5 w-3.5" />} onClick={() => setCompare((c) => !c)} aria-pressed={compare}>
                  Comparar
                </Button>
                <Button size="sm" variant="ghost" icon={<RotateCcw className="h-3.5 w-3.5" />} onClick={() => setState(EMPTY_STATE)} disabled={!hasAnyTint(state)}>
                  Limpar
                </Button>
              </div>
            </div>

            <Card className="overflow-hidden">
              {source?.mode === 'imagem' && source.image ? (
                <ImageSource image={source.image} visual={visual} compare={compare} split={split} onSplitChange={setSplitBoth} alt={`Simulação de película em ${vehicleName(vehicle)}`} />
              ) : source?.mode === 'modelo_3d' && vehicle.model_3d_path ? (
                <ModelSource vehicle={vehicle} visual={visual} compare={compare} split={split} splitRef={splitRef} onSplitChange={setSplitBoth} />
              ) : (
                <div className="relative">
                  <Stage className="aspect-[16/10] w-full" compare={compare} splitRef={splitRef} fitKey={`ref-${vehicle.category}`}>
                    <ReferenceCarModel kind={referenceKindFor(vehicle.category)} visual={visual} />
                  </Stage>
                  {compare && <CompareHandle value={split} onChange={setSplitBoth} />}
                  <div className="pointer-events-none absolute inset-x-3 bottom-3 flex justify-center">
                    <p className="flex items-center gap-2 rounded-md border border-neutral-300 bg-white/95 px-3 py-2 text-xs text-neutral-700 shadow-soft">
                      <Info className="h-3.5 w-3.5 shrink-0" />
                      Modelo genérico de referência ({REFERENCE_LABELS[referenceKindFor(vehicle.category)]}) — não representa o {vehicle.brand} {vehicle.model}.
                    </p>
                  </div>
                </div>
              )}
            </Card>

            <div className="flex flex-wrap items-center gap-2 text-xs text-neutral-500">
              <Badge tone="muted">{CATEGORY_LABELS[vehicle.category]}</Badge>
              {source?.mode === 'imagem' && source.image && <span>Origem da imagem: {source.image.source_credit}</span>}
              {source?.mode === 'modelo_3d' && <span>Origem do modelo: {vehicle.model_3d_credit}</span>}
              {sources.length === 1 && (
                <span className="inline-flex items-center gap-1">
                  <ImageIcon className="h-3.5 w-3.5" /> Cadastre imagens com máscaras ou um modelo 3D na garagem para a simulação real.
                </span>
              )}
              {source?.mode !== 'imagem' && <span>Arraste para girar o veículo; use a rolagem para aproximar.</span>}
            </div>
          </div>

          <div className="space-y-4">
            <Card>
              <CardBody className="space-y-4">
                <div>
                  <p className="eyebrow mb-1.5">Aplicar em todos os vidros</p>
                  <FilmSelect value="__" placeholder="Escolha uma película ou nível…" onChange={applyAll} films={activeFilms} recommendedIds={recommendedIds} emptyLabel="Remover de todos" />
                </div>
                {activeFilms.length === 0 && (
                  <p className="flex items-start gap-2 rounded-md bg-neutral-50 p-3 text-xs text-neutral-600">
                    <AlertTriangle className="mt-px h-3.5 w-3.5 shrink-0" />
                    O catálogo de películas está vazio. Use "Nível personalizado" ou cadastre películas no catálogo.
                  </p>
                )}
              </CardBody>
            </Card>
            <Card>
              <CardBody>
                <ZoneControls
                  state={state}
                  onChange={(zone, setting) => {
                    setSaved(null)
                    setState((s) => ({ ...s, [zone]: setting }))
                  }}
                  films={activeFilms}
                  recommendedIds={recommendedIds}
                  limits={limits}
                  hiddenZones={hiddenZones}
                />
              </CardBody>
            </Card>

            {saved ? (
              <div className="space-y-3">
                <FormSuccess message="Simulação salva com sucesso." />
                <div className="flex flex-wrap gap-2">
                  {can('orcamentos.gerenciar') && (
                    <Button icon={<FileText className="h-4 w-4" />} onClick={() => navigate(`/app/orcamentos/novo?simulacao=${saved.id}`)}>
                      Gerar orçamento
                    </Button>
                  )}
                  <Button variant="secondary" onClick={() => setSaved(null)}>
                    Continuar simulando
                  </Button>
                </div>
              </div>
            ) : (
              <Button className="w-full" size="lg" icon={<Save className="h-4 w-4" />} disabled={!hasAnyTint(state)} onClick={() => setSaving(true)}>
                Salvar simulação
              </Button>
            )}

            <p className="text-[11px] leading-relaxed text-neutral-500">
              Simulação aproximada: a aparência real varia com a iluminação, a cor do vidro original e o ângulo de visão. As referências mínimas de transmissão luminosa são
              configuráveis e devem ser conferidas na legislação vigente (CONTRAN), considerando o conjunto vidro + película.
            </p>
          </div>
        </div>
      )}

      <SaveSimulationModal
        open={saving}
        onClose={() => setSaving(false)}
        initialCustomerId={customerParam}
        draft={
          vehicle && source
            ? { vehicle_id: vehicle.id, vehicle_image_id: source.image?.id ?? null, mode: source.mode, config: stateToConfig(state) }
            : null
        }
        onSaved={(sim) => {
          setSaving(false)
          setSaved(sim)
          toast.success('Simulação salva.')
        }}
      />
    </>
  )
}

function ImageSource({
  image,
  visual,
  compare,
  split,
  onSplitChange,
  alt,
}: {
  image: VehicleImage
  visual: ReturnType<typeof stateToVisual>
  compare: boolean
  split: number
  onSplitChange: (v: number) => void
  alt: string
}) {
  const { url, isLoading } = useSignedUrl(image.storage_path)
  const [dims, setDims] = useState<{ w: number; h: number } | null>(null)
  const w = image.width ?? dims?.w
  const h = image.height ?? dims?.h
  if (!url || !w || !h) {
    return (
      <div className="relative aspect-[16/10] w-full">
        <Skeleton className="absolute inset-0 rounded-none" />
        {url && <img src={url} alt="" className="hidden" onLoad={(e) => setDims({ w: e.currentTarget.naturalWidth, h: e.currentTarget.naturalHeight })} />}
        {!isLoading && !url && <p className="absolute inset-0 flex items-center justify-center text-sm text-neutral-500">Imagem indisponível.</p>}
      </div>
    )
  }
  return <ImageTintView url={url} width={w} height={h} masks={image.glass_masks} visual={visual} compare={compare} split={split} onSplitChange={onSplitChange} alt={alt} />
}

function ModelSource({
  vehicle,
  visual,
  compare,
  split,
  splitRef,
  onSplitChange,
}: {
  vehicle: VehicleWithMedia
  visual: ReturnType<typeof stateToVisual>
  compare: boolean
  split: number
  splitRef: MutableRefObject<number>
  onSplitChange: (v: number) => void
}) {
  const { url } = useSignedUrl(vehicle.model_3d_path)
  const unmapped = Object.keys(vehicle.model_3d_glass_map ?? {}).length === 0
  return (
    <div className="relative">
      <ErrorBoundary
        resetKey={url}
        fallback={() => (
          <div className="flex aspect-[16/10] items-center justify-center">
            <EmptyState icon={Box} title="Não foi possível abrir o modelo 3D" description="Verifique o arquivo na garagem ou use outra mídia." />
          </div>
        )}
      >
        {url ? (
          <Stage className="aspect-[16/10] w-full" compare={compare} splitRef={splitRef} fitKey={url}>
            <GltfCarModel url={url} glassMap={vehicle.model_3d_glass_map ?? {}} visual={visual} />
          </Stage>
        ) : (
          <Skeleton className="aspect-[16/10] w-full rounded-none" />
        )}
      </ErrorBoundary>
      {compare && <CompareHandle value={split} onChange={onSplitChange} />}
      {unmapped && (
        <div className="pointer-events-none absolute inset-x-3 bottom-3 flex justify-center">
          <p className="flex items-center gap-2 rounded-md border border-neutral-300 bg-white/95 px-3 py-2 text-xs text-neutral-700 shadow-soft">
            <SunDim className="h-3.5 w-3.5" /> Os vidros deste modelo ainda não foram mapeados na garagem.
          </p>
        </div>
      )}
    </div>
  )
}
