import { useLayoutEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button, Field, FormError, Input, Modal, Select, Switch, Textarea, useToast } from '@/components/ui'
import { CATEGORIES, CATEGORY_LABELS } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import { intField, toNullableNumber } from '@/lib/validation'
import type { Vehicle, VehicleCategory } from '@/types/domain'
import { useSaveVehicle } from './api'

const currentYear = new Date().getFullYear()

const schema = z
  .object({
    brand: z.string().trim().min(1, 'Informe a marca.').max(60, 'Máximo de 60 caracteres.'),
    model: z.string().trim().min(1, 'Informe o modelo.').max(80, 'Máximo de 80 caracteres.'),
    generation: z.string().trim().max(80, 'Máximo de 80 caracteres.'),
    year_start: intField({ required: false, min: 1950, max: currentYear + 2 }),
    year_end: intField({ required: false, min: 1950, max: currentYear + 2 }),
    category: z.enum(CATEGORIES as [VehicleCategory, ...VehicleCategory[]]),
    doors: z.string(),
    notes: z.string().max(2000, 'Máximo de 2000 caracteres.'),
  })
  .refine((v) => !v.year_start || !v.year_end || Number(v.year_end) >= Number(v.year_start), {
    path: ['year_end'],
    message: 'O ano final deve ser igual ou posterior ao inicial.',
  })
type FormValues = z.infer<typeof schema>

function defaults(v?: Vehicle | null): FormValues {
  return {
    brand: v?.brand ?? '',
    model: v?.model ?? '',
    generation: v?.generation ?? '',
    year_start: v?.year_start?.toString() ?? '',
    year_end: v?.year_end?.toString() ?? '',
    category: v?.category ?? 'hatch',
    doors: v?.doors?.toString() ?? '',
    notes: v?.notes ?? '',
  }
}

export function VehicleFormModal({
  open,
  onClose,
  vehicle,
  brands = [],
  onSaved,
}: {
  open: boolean
  onClose: () => void
  vehicle?: Vehicle | null
  brands?: string[]
  onSaved?: (v: Vehicle) => void
}) {
  const toast = useToast()
  const save = useSaveVehicle()
  const [active, setActive] = useState(vehicle?.active ?? true)
  const [formError, setFormError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: defaults(vehicle) })

  useLayoutEffect(() => {
    if (open) {
      reset(defaults(vehicle))
      setActive(vehicle?.active ?? true)
      setFormError(null)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, vehicle?.id])

  const onSubmit = async (values: FormValues) => {
    setFormError(null)
    try {
      const saved = await save.mutateAsync({
        id: vehicle?.id,
        input: {
          brand: values.brand.trim(),
          model: values.model.trim(),
          generation: values.generation.trim(),
          year_start: toNullableNumber(values.year_start),
          year_end: toNullableNumber(values.year_end),
          category: values.category,
          doors: values.doors ? Number(values.doors) : null,
          notes: values.notes.trim(),
          active,
        },
      })
      toast.success(vehicle ? 'Veículo atualizado.' : 'Veículo cadastrado na garagem.')
      onSaved?.(saved)
      onClose()
    } catch (err) {
      setFormError(toMessage(err))
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={vehicle ? 'Editar veículo' : 'Novo veículo'}
      description="Cadastre o modelo com a geração e o período de fabricação."
      size="lg"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" form="vehicle-form" loading={isSubmitting}>
            {vehicle ? 'Salvar alterações' : 'Cadastrar veículo'}
          </Button>
        </>
      }
    >
      <form id="vehicle-form" onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
        <FormError message={formError} />
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Marca" required error={errors.brand?.message}>
            <Input list="vehicle-brands" placeholder="Ex.: Volkswagen" {...register('brand')} />
          </Field>
          <datalist id="vehicle-brands">
            {brands.map((b) => (
              <option key={b} value={b} />
            ))}
          </datalist>
          <Field label="Modelo" required error={errors.model?.message}>
            <Input placeholder="Ex.: Polo" {...register('model')} />
          </Field>
          <Field label="Geração / versão" error={errors.generation?.message} hint="Ex.: 6ª geração, G7, Novo Uno">
            <Input {...register('generation')} />
          </Field>
          <Field label="Categoria" required error={errors.category?.message}>
            <Select {...register('category')}>
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {CATEGORY_LABELS[c]}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Ano inicial" error={errors.year_start?.message}>
            <Input inputMode="numeric" placeholder="Ex.: 2018" {...register('year_start')} />
          </Field>
          <Field label="Ano final" error={errors.year_end?.message} hint="Deixe em branco se ainda é fabricado.">
            <Input inputMode="numeric" placeholder="Atual" {...register('year_end')} />
          </Field>
          <Field label="Portas" error={errors.doors?.message}>
            <Select {...register('doors')}>
              <option value="">Não informado</option>
              {[2, 3, 4, 5].map((d) => (
                <option key={d} value={d}>
                  {d} portas
                </option>
              ))}
            </Select>
          </Field>
          <div className="flex items-end pb-2">
            <label className="flex items-center gap-3 text-sm text-neutral-800">
              <Switch checked={active} onChange={setActive} label="Veículo ativo" /> Disponível no simulador e orçamentos
            </label>
          </div>
        </div>
        <Field label="Observações" error={errors.notes?.message}>
          <Textarea rows={3} {...register('notes')} />
        </Field>
      </form>
    </Modal>
  )
}
