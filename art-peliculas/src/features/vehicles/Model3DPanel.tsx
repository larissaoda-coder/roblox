import { useCallback, useEffect, useMemo, useState } from 'react'
import { AlertTriangle, Box, Sparkles, Trash2, Upload } from 'lucide-react'
import { Badge, Button, Card, CardBody, CardHeader, Checkbox, EmptyState, Field, FormError, Select, Textarea, useConfirm, useToast } from '@/components/ui'
import { ZONES, ZONE_LABELS } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import { useSignedUrl } from '@/lib/storage'
import { vltToOpacity } from '@/lib/tint'
import type { GlassMap, GlassZone, Vehicle } from '@/types/domain'
import { Stage } from '@/features/three/Stage'
import { GltfCarModel } from '@/features/three/CarModels'
import { suggestZone, type MeshInfo, type TintVisual } from '@/features/three/materials'
import { ErrorBoundary } from '@/features/shared/ErrorBoundary'
import { useRemoveModel, useSaveGlassMap, useUploadModel } from './api'

const PREVIEW: TintVisual = Object.fromEntries(ZONES.map((z) => [z, { opacity: vltToOpacity(20), finish: 'neutra' as const }]))

export function Model3DPanel({ vehicle, canEdit }: { vehicle: Vehicle; canEdit: boolean }) {
  const { url, isLoading: urlLoading } = useSignedUrl(vehicle.model_3d_path)
  const [meshes, setMeshes] = useState<MeshInfo[]>([])
  const [map, setMap] = useState<GlassMap>(vehicle.model_3d_glass_map ?? {})
  const [selected, setSelected] = useState<string | null>(null)
  const [onlyGlass, setOnlyGlass] = useState(true)
  const [preview, setPreview] = useState(true)
  const [replacing, setReplacing] = useState(false)
  const saveMap = useSaveGlassMap()
  const removeModel = useRemoveModel()
  const toast = useToast()
  const confirm = useConfirm()

  useEffect(() => setMap(vehicle.model_3d_glass_map ?? {}), [vehicle.model_3d_glass_map, vehicle.model_3d_path])

  const onMeshes = useCallback((list: MeshInfo[]) => setMeshes(list), [])
  const dirty = JSON.stringify(map) !== JSON.stringify(vehicle.model_3d_glass_map ?? {})
  const visible = useMemo(() => meshes.filter((m) => !onlyGlass || m.glassLike || map[m.key] || m.key === selected), [meshes, onlyGlass, map, selected])
  const mappedCount = Object.keys(map).length

  if (!vehicle.model_3d_path || replacing) {
    return (
      <Card>
        <CardHeader title="Modelo 3D" description="Formato .glb (glTF binário), até 50 MB." />
        <CardBody>
          {canEdit ? (
            <ModelUploadForm vehicle={vehicle} onDone={() => setReplacing(false)} onCancel={vehicle.model_3d_path ? () => setReplacing(false) : undefined} />
          ) : (
            <EmptyState icon={Box} title="Sem modelo 3D" description="Nenhum modelo 3D foi cadastrado para este veículo." />
          )}
        </CardBody>
      </Card>
    )
  }

  const setZone = (key: string, zone: GlassZone | '') => {
    setMap((m) => {
      const next = { ...m }
      if (zone) next[key] = zone
      else delete next[key]
      return next
    })
  }

  const autoSuggest = () => {
    const next = { ...map }
    let count = 0
    for (const info of meshes) {
      if (next[info.key]) continue
      const z = suggestZone(info)
      if (z) {
        next[info.key] = z
        count++
      }
    }
    setMap(next)
    if (count) toast.info(`${count} malha(s) associadas pelo nome. Revise antes de salvar.`)
    else toast.info('Nenhuma sugestão encontrada pelos nomes das malhas.')
  }

  return (
    <Card>
      <CardHeader
        title="Modelo 3D"
        description={`${mappedCount} malha(s) de vidro mapeadas · Origem: ${vehicle.model_3d_credit}`}
        actions={
          canEdit && (
            <>
              <Button size="sm" variant="secondary" icon={<Upload className="h-3.5 w-3.5" />} onClick={() => setReplacing(true)}>
                Substituir
              </Button>
              <Button
                size="sm"
                variant="ghost"
                icon={<Trash2 className="h-3.5 w-3.5" />}
                onClick={async () => {
                  const ok = await confirm({ title: 'Remover modelo 3D?', description: 'O arquivo e o mapeamento dos vidros serão excluídos.', destructive: true, confirmLabel: 'Remover' })
                  if (!ok) return
                  try {
                    await removeModel.mutateAsync(vehicle)
                    toast.success('Modelo 3D removido.')
                  } catch (err) {
                    toast.error(toMessage(err))
                  }
                }}
              >
                Remover
              </Button>
            </>
          )
        }
      />
      <div className="grid gap-0 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]">
        <div className="relative border-b border-neutral-200 lg:border-b-0 lg:border-r">
          <ErrorBoundary
            resetKey={url}
            fallback={(error) => (
              <div className="flex aspect-[4/3] items-center justify-center p-6">
                <EmptyState icon={AlertTriangle} title="Não foi possível abrir o modelo" description={toMessage(error, 'O arquivo .glb parece inválido ou corrompido.')} />
              </div>
            )}
          >
            {url ? (
              <Stage className="aspect-[4/3] w-full" fitKey={url}>
                <GltfCarModel url={url} glassMap={map} visual={preview ? PREVIEW : null} selectedKey={selected} onMeshes={onMeshes} onPick={canEdit ? setSelected : undefined} />
              </Stage>
            ) : (
              <div className="flex aspect-[4/3] items-center justify-center text-sm text-neutral-500">{urlLoading ? 'Carregando…' : 'Arquivo indisponível.'}</div>
            )}
          </ErrorBoundary>
          <div className="absolute bottom-3 left-3 flex gap-2">
            <Button size="sm" variant="secondary" onClick={() => setPreview((p) => !p)}>
              {preview ? 'Ver vidros originais' : 'Pré-visualizar película 20%'}
            </Button>
          </div>
        </div>
        <div className="flex max-h-[560px] flex-col">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-neutral-200 px-4 py-3">
            <Checkbox checked={onlyGlass} onChange={(e) => setOnlyGlass(e.target.checked)} label="Somente prováveis vidros" />
            {canEdit && (
              <Button size="sm" variant="ghost" icon={<Sparkles className="h-3.5 w-3.5" />} onClick={autoSuggest} disabled={!meshes.length}>
                Sugerir pelo nome
              </Button>
            )}
          </div>
          <ul className="scrollbar-thin flex-1 divide-y divide-neutral-100 overflow-y-auto">
            {meshes.length === 0 && <li className="px-4 py-8 text-center text-sm text-neutral-500">Carregando malhas do modelo…</li>}
            {meshes.length > 0 && visible.length === 0 && (
              <li className="px-4 py-8 text-center text-sm text-neutral-500">Nenhuma malha identificada como vidro. Desmarque o filtro para ver todas.</li>
            )}
            {visible.map((m) => (
              <li
                key={m.key}
                className={`flex items-center gap-3 px-4 py-2.5 ${selected === m.key ? 'bg-neutral-100' : ''}`}
                onMouseEnter={() => canEdit && setSelected(m.key)}
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[13px] font-medium text-neutral-900">{m.name}</p>
                  <p className="truncate text-[11px] text-neutral-500">
                    {m.materialName || 'material sem nome'}
                    {m.glassLike && ' · transparente'}
                  </p>
                </div>
                {canEdit ? (
                  <Select className="h-8 w-44 text-xs" value={map[m.key] ?? ''} onChange={(e) => setZone(m.key, e.target.value as GlassZone | '')} aria-label={`Zona da malha ${m.name}`}>
                    <option value="">Não é vidro com película</option>
                    {ZONES.map((z) => (
                      <option key={z} value={z}>
                        {ZONE_LABELS[z]}
                      </option>
                    ))}
                  </Select>
                ) : (
                  map[m.key] && <Badge tone="outline">{ZONE_LABELS[map[m.key]]}</Badge>
                )}
              </li>
            ))}
          </ul>
          {canEdit && (
            <div className="flex items-center justify-between gap-2 border-t border-neutral-200 px-4 py-3">
              <p className="text-xs text-neutral-500">Clique em uma peça no modelo para localizá-la.</p>
              <Button
                size="sm"
                disabled={!dirty}
                loading={saveMap.isPending}
                onClick={async () => {
                  try {
                    await saveMap.mutateAsync({ vehicleId: vehicle.id, map })
                    toast.success('Mapeamento dos vidros salvo.')
                  } catch (err) {
                    toast.error(toMessage(err))
                  }
                }}
              >
                Salvar mapeamento
              </Button>
            </div>
          )}
        </div>
      </div>
    </Card>
  )
}

function ModelUploadForm({ vehicle, onDone, onCancel }: { vehicle: Vehicle; onDone: () => void; onCancel?: () => void }) {
  const upload = useUploadModel()
  const toast = useToast()
  const [file, setFile] = useState<File | null>(null)
  const [credit, setCredit] = useState('')
  const [error, setError] = useState<string | null>(null)

  const submit = async () => {
    setError(null)
    if (!file) return setError('Selecione o arquivo .glb do modelo.')
    if (credit.trim().length < 3) return setError('Informe a origem e a licença/autorização de uso do modelo.')
    try {
      await upload.mutateAsync({ vehicle, file, credit })
      toast.success('Modelo 3D enviado. Agora associe as malhas de vidro às zonas.')
      onDone()
    } catch (err) {
      setError(toMessage(err, err instanceof Error ? err.message : undefined))
    }
  }

  return (
    <div className="space-y-4">
      <FormError message={error} />
      <p className="text-sm text-neutral-600">
        Use somente modelos realistas do próprio veículo, com licença ou autorização de uso. Não cadastre modelos genéricos como se fossem do{' '}
        {vehicle.brand} {vehicle.model}.
      </p>
      <Field label="Arquivo do modelo (.glb)" required>
        <input
          type="file"
          accept=".glb,model/gltf-binary"
          onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          className="block w-full text-sm text-neutral-700 file:mr-3 file:rounded-md file:border file:border-neutral-300 file:bg-white file:px-3 file:py-2 file:text-sm file:font-medium file:text-neutral-900 hover:file:bg-neutral-50"
        />
      </Field>
      <Field label="Origem e licença" required hint="Ex.: Modelo adquirido na loja X, licença comercial nº 123.">
        <Textarea rows={2} value={credit} onChange={(e) => setCredit(e.target.value)} maxLength={300} />
      </Field>
      <div className="flex justify-end gap-2">
        {onCancel && (
          <Button variant="secondary" onClick={onCancel}>
            Cancelar
          </Button>
        )}
        <Button icon={<Upload className="h-4 w-4" />} loading={upload.isPending} onClick={submit}>
          Enviar modelo
        </Button>
      </div>
    </div>
  )
}
