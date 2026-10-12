import { useLayoutEffect, useState } from 'react'
import { useFieldArray, useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Info, Plus, X } from 'lucide-react'
import { Button, Field, FormError, Input, Modal, Select, Switch, Textarea, useToast } from '@/components/ui'
import { FINISH_LABELS, PRICE_UNIT_LABELS } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import { parseDecimal } from '@/lib/format'
import { decimalField, intField, toNullableNumber } from '@/lib/validation'
import type { Film, FilmFinish, FilmPriceUnit } from '@/types/domain'
import { useSaveFilm } from './api'

const schema = z.object({
  name: z.string().trim().min(1, 'Informe o nome.').max(100, 'Máximo de 100 caracteres.'),
  manufacturer: z.string().trim().min(1, 'Informe o fabricante.').max(80, 'Máximo de 80 caracteres.'),
  product_line: z.string().trim().max(80, 'Máximo de 80 caracteres.'),
  vlt_percent: decimalField({ min: 0, max: 100, label: 'a transmissão luminosa' }),
  finish: z.enum(['neutra', 'refletiva']),
  price: decimalField({ min: 0, label: 'o preço' }),
  price_unit: z.enum(['veiculo', 'vidro', 'm2']),
  uv_rejection_percent: decimalField({ min: 0, max: 100, required: false }),
  ir_rejection_percent: decimalField({ min: 0, max: 100, required: false }),
  tser_percent: decimalField({ min: 0, max: 100, required: false }),
  warranty_years: intField({ min: 0, max: 50, required: false }),
  description: z.string().max(2000, 'Máximo de 2000 caracteres.'),
  technical_specs: z
    .array(z.object({ label: z.string().trim().min(1, 'Informe o nome.').max(60), value: z.string().trim().min(1, 'Informe o valor.').max(200) }))
    .max(30, 'Máximo de 30 características.'),
})
type FormValues = z.infer<typeof schema>

const str = (v: number | null | undefined) => (v === null || v === undefined ? '' : String(v).replace('.', ','))

function defaults(f?: Film | null): FormValues {
  return {
    name: f?.name ?? '',
    manufacturer: f?.manufacturer ?? '',
    product_line: f?.product_line ?? '',
    vlt_percent: str(f?.vlt_percent),
    finish: f?.finish ?? 'neutra',
    price: str(f?.price),
    price_unit: f?.price_unit ?? 'veiculo',
    uv_rejection_percent: str(f?.uv_rejection_percent),
    ir_rejection_percent: str(f?.ir_rejection_percent),
    tser_percent: str(f?.tser_percent),
    warranty_years: str(f?.warranty_years),
    description: f?.description ?? '',
    technical_specs: f?.technical_specs ?? [],
  }
}

export function FilmFormModal({ open, onClose, film, manufacturers = [] }: { open: boolean; onClose: () => void; film?: Film | null; manufacturers?: string[] }) {
  const save = useSaveFilm()
  const toast = useToast()
  const [active, setActive] = useState(true)
  const [formError, setFormError] = useState<string | null>(null)
  const {
    register,
    control,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: defaults(film) })
  const specs = useFieldArray({ control, name: 'technical_specs' })

  useLayoutEffect(() => {
    if (open) {
      reset(defaults(film))
      setActive(film?.active ?? true)
      setFormError(null)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, film?.id])

  const onSubmit = async (v: FormValues) => {
    setFormError(null)
    try {
      await save.mutateAsync({
        id: film?.id,
        input: {
          name: v.name.trim(),
          manufacturer: v.manufacturer.trim(),
          product_line: v.product_line.trim(),
          vlt_percent: parseDecimal(v.vlt_percent),
          finish: v.finish as FilmFinish,
          price: parseDecimal(v.price),
          price_unit: v.price_unit as FilmPriceUnit,
          uv_rejection_percent: toNullableNumber(v.uv_rejection_percent),
          ir_rejection_percent: toNullableNumber(v.ir_rejection_percent),
          tser_percent: toNullableNumber(v.tser_percent),
          warranty_years: toNullableNumber(v.warranty_years),
          description: v.description.trim(),
          technical_specs: v.technical_specs.map((s) => ({ label: s.label.trim(), value: s.value.trim() })),
          active,
        },
      })
      toast.success(film ? 'Película atualizada.' : 'Película cadastrada no catálogo.')
      onClose()
    } catch (err) {
      setFormError(toMessage(err))
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={film ? 'Editar película' : 'Nova película'}
      size="xl"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" form="film-form" loading={isSubmitting}>
            {film ? 'Salvar alterações' : 'Cadastrar película'}
          </Button>
        </>
      }
    >
      <form id="film-form" onSubmit={handleSubmit(onSubmit)} className="space-y-6" noValidate>
        <FormError message={formError} />
        <p className="flex items-start gap-2 rounded-md bg-neutral-50 p-3 text-xs leading-relaxed text-neutral-600">
          <Info className="mt-px h-3.5 w-3.5 shrink-0" />
          Informe somente dados técnicos fornecidos pelo fabricante (ficha técnica ou embalagem). Deixe em branco o que não for informado.
        </p>

        <section className="grid gap-4 sm:grid-cols-3">
          <Field label="Nome do produto" required error={errors.name?.message} className="sm:col-span-1">
            <Input placeholder="Ex.: G20" {...register('name')} />
          </Field>
          <Field label="Fabricante" required error={errors.manufacturer?.message}>
            <Input list="film-manufacturers" {...register('manufacturer')} />
          </Field>
          <datalist id="film-manufacturers">
            {manufacturers.map((m) => (
              <option key={m} value={m} />
            ))}
          </datalist>
          <Field label="Linha" error={errors.product_line?.message}>
            <Input placeholder="Ex.: Nano cerâmica" {...register('product_line')} />
          </Field>
          <Field label="Transmissão luminosa (VLT %)" required error={errors.vlt_percent?.message} hint="Percentual de luz visível que atravessa a película.">
            <Input inputMode="decimal" placeholder="Ex.: 20" {...register('vlt_percent')} />
          </Field>
          <Field label="Aparência na simulação" error={errors.finish?.message}>
            <Select {...register('finish')}>
              {(Object.keys(FINISH_LABELS) as FilmFinish[]).map((f) => (
                <option key={f} value={f}>
                  {FINISH_LABELS[f]}
                </option>
              ))}
            </Select>
          </Field>
          <div className="grid grid-cols-[1fr_auto] gap-2">
            <Field label="Preço (R$)" required error={errors.price?.message}>
              <Input inputMode="decimal" placeholder="0,00" {...register('price')} />
            </Field>
            <Field label="Unidade" error={errors.price_unit?.message}>
              <Select {...register('price_unit')} className="w-32">
                {(Object.keys(PRICE_UNIT_LABELS) as FilmPriceUnit[]).map((u) => (
                  <option key={u} value={u}>
                    {PRICE_UNIT_LABELS[u]}
                  </option>
                ))}
              </Select>
            </Field>
          </div>
        </section>

        <section>
          <p className="eyebrow mb-3">Características técnicas (opcionais)</p>
          <div className="grid gap-4 sm:grid-cols-4">
            <Field label="Rejeição UV (%)" error={errors.uv_rejection_percent?.message}>
              <Input inputMode="decimal" {...register('uv_rejection_percent')} />
            </Field>
            <Field label="Rejeição de IR (%)" error={errors.ir_rejection_percent?.message}>
              <Input inputMode="decimal" {...register('ir_rejection_percent')} />
            </Field>
            <Field label="Rejeição total de energia (TSER %)" error={errors.tser_percent?.message}>
              <Input inputMode="decimal" {...register('tser_percent')} />
            </Field>
            <Field label="Garantia (anos)" error={errors.warranty_years?.message}>
              <Input inputMode="numeric" {...register('warranty_years')} />
            </Field>
          </div>
          <div className="mt-4 space-y-2">
            {specs.fields.map((f, i) => (
              <div key={f.id} className="grid grid-cols-[1fr_1.5fr_auto] items-start gap-2">
                <Field error={errors.technical_specs?.[i]?.label?.message}>
                  <Input placeholder="Característica (ex.: Espessura)" aria-label="Nome da característica" {...register(`technical_specs.${i}.label`)} />
                </Field>
                <Field error={errors.technical_specs?.[i]?.value?.message}>
                  <Input placeholder="Valor (ex.: 1,5 mil)" aria-label="Valor da característica" {...register(`technical_specs.${i}.value`)} />
                </Field>
                <Button variant="ghost" size="icon" aria-label="Remover característica" onClick={() => specs.remove(i)}>
                  <X className="h-4 w-4" />
                </Button>
              </div>
            ))}
            <Button variant="ghost" size="sm" icon={<Plus className="h-3.5 w-3.5" />} onClick={() => specs.append({ label: '', value: '' })} disabled={specs.fields.length >= 30}>
              Adicionar característica
            </Button>
          </div>
        </section>

        <Field label="Descrição" error={errors.description?.message}>
          <Textarea rows={3} {...register('description')} />
        </Field>

        <label className="flex items-center gap-3 text-sm text-neutral-800">
          <Switch checked={active} onChange={setActive} label="Película ativa" /> Disponível no simulador e em novos orçamentos
        </label>
      </form>
    </Modal>
  )
}
