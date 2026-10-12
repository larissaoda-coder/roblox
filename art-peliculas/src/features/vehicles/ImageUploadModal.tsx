import { useEffect, useLayoutEffect, useState } from 'react'
import { ImagePlus } from 'lucide-react'
import { Button, Checkbox, Field, FormError, Modal, Select, Textarea, useToast } from '@/components/ui'
import { VIEWS, VIEW_LABELS } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import type { ImageView, VehicleImage, VehicleWithMedia } from '@/types/domain'
import { useAddVehicleImage } from './api'

export function ImageUploadModal({
  open,
  onClose,
  vehicle,
  onUploaded,
}: {
  open: boolean
  onClose: () => void
  vehicle: VehicleWithMedia
  onUploaded?: (img: VehicleImage) => void
}) {
  const add = useAddVehicleImage()
  const toast = useToast()
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [view, setView] = useState<ImageView>('frente_34')
  const [credit, setCredit] = useState('')
  const [primary, setPrimary] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useLayoutEffect(() => {
    if (!open) return
    setFile(null)
    setView('frente_34')
    setCredit('')
    setPrimary(vehicle.vehicle_images.length === 0)
    setError(null)
  }, [open, vehicle.vehicle_images.length])

  useEffect(() => {
    if (!file) return setPreview(null)
    const url = URL.createObjectURL(file)
    setPreview(url)
    return () => URL.revokeObjectURL(url)
  }, [file])

  const submit = async () => {
    setError(null)
    if (!file) return setError('Selecione uma imagem.')
    if (credit.trim().length < 3) return setError('Informe a origem e a autorização de uso da imagem.')
    try {
      const img = await add.mutateAsync({ vehicle, file, view, credit, primary })
      toast.success('Imagem adicionada. Desenhe as máscaras dos vidros para usá-la no simulador.')
      onUploaded?.(img)
      onClose()
    } catch (err) {
      setError(toMessage(err, err instanceof Error ? err.message : undefined))
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Adicionar imagem autorizada"
      description={`${vehicle.brand} ${vehicle.model} ${vehicle.generation}`}
      size="lg"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button loading={add.isPending} onClick={submit}>
            Enviar imagem
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <FormError message={error} />
        <label className="flex aspect-[16/9] cursor-pointer flex-col items-center justify-center overflow-hidden rounded-lg border border-dashed border-neutral-300 bg-neutral-50 text-neutral-500 transition-colors hover:border-neutral-500 hover:bg-neutral-100">
          {preview ? (
            <img src={preview} alt="Pré-visualização" className="h-full w-full object-contain" />
          ) : (
            <>
              <ImagePlus className="h-7 w-7" strokeWidth={1.4} />
              <span className="mt-2 text-sm font-medium text-neutral-700">Selecionar imagem</span>
              <span className="text-xs">JPG, PNG ou WebP · fundo neutro de preferência</span>
            </>
          )}
          <input type="file" accept="image/jpeg,image/png,image/webp" className="sr-only" onChange={(e) => setFile(e.target.files?.[0] ?? null)} aria-label="Arquivo de imagem" />
        </label>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Vista" hint="Frente 3/4 mostra para-brisa e laterais; traseira 3/4 mostra o vidro traseiro.">
            <Select value={view} onChange={(e) => setView(e.target.value as ImageView)}>
              {VIEWS.map((v) => (
                <option key={v} value={v}>
                  {VIEW_LABELS[v]}
                </option>
              ))}
            </Select>
          </Field>
          <div className="flex items-end pb-2">
            <Checkbox checked={primary} onChange={(e) => setPrimary(e.target.checked)} label="Usar como imagem principal" />
          </div>
        </div>
        <Field label="Origem e autorização de uso" required hint="Ex.: Foto própria da loja (cliente autorizou), imagem cedida pela concessionária X.">
          <Textarea rows={2} value={credit} onChange={(e) => setCredit(e.target.value)} maxLength={300} />
        </Field>
        <p className="text-xs text-neutral-500">
          A imagem deve mostrar exatamente este modelo/geração. Imagens são exibidas sem filtros; apenas as áreas de vidro marcadas recebem a simulação.
        </p>
      </div>
    </Modal>
  )
}
