import { useLayoutEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button, Field, FormError, Input, Modal, Switch, Textarea, useToast } from '@/components/ui'
import { toMessage } from '@/lib/errors'
import { parseDecimal } from '@/lib/format'
import { decimalField, intField, toNullableNumber } from '@/lib/validation'
import type { ServiceType } from '@/types/domain'
import { useSaveServiceType } from './api'

const schema = z.object({
  name: z.string().trim().min(2, 'Informe o nome.').max(100, 'Máximo de 100 caracteres.'),
  description: z.string().max(1000, 'Máximo de 1000 caracteres.'),
  base_price: decimalField({ min: 0, label: 'o preço base' }),
  estimated_minutes: intField({ min: 1, max: 10080, required: false }),
})
type FormValues = z.infer<typeof schema>

export function ServiceTypeFormModal({ open, onClose, type }: { open: boolean; onClose: () => void; type?: ServiceType | null }) {
  const save = useSaveServiceType()
  const toast = useToast()
  const [active, setActive] = useState(true)
  const [formError, setFormError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema) })

  useLayoutEffect(() => {
    if (!open) return
    reset({
      name: type?.name ?? '',
      description: type?.description ?? '',
      base_price: type ? String(type.base_price).replace('.', ',') : '',
      estimated_minutes: type?.estimated_minutes?.toString() ?? '',
    })
    setActive(type?.active ?? true)
    setFormError(null)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, type?.id])

  const onSubmit = async (v: FormValues) => {
    setFormError(null)
    try {
      await save.mutateAsync({
        id: type?.id,
        input: {
          name: v.name.trim(),
          description: v.description.trim(),
          base_price: parseDecimal(v.base_price),
          estimated_minutes: toNullableNumber(v.estimated_minutes),
          active,
        },
      })
      toast.success(type ? 'Tipo de serviço atualizado.' : 'Tipo de serviço cadastrado.')
      onClose()
    } catch (err) {
      setFormError(toMessage(err))
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={type ? 'Editar tipo de serviço' : 'Novo tipo de serviço'}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" form="service-type-form" loading={isSubmitting}>
            Salvar
          </Button>
        </>
      }
    >
      <form id="service-type-form" onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
        <FormError message={formError} />
        <Field label="Nome" required error={errors.name?.message}>
          <Input placeholder="Ex.: Remoção de película antiga" {...register('name')} />
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Preço base (R$)" required error={errors.base_price?.message}>
            <Input inputMode="decimal" placeholder="0,00" {...register('base_price')} />
          </Field>
          <Field label="Tempo estimado (min)" error={errors.estimated_minutes?.message}>
            <Input inputMode="numeric" {...register('estimated_minutes')} />
          </Field>
        </div>
        <Field label="Descrição" error={errors.description?.message}>
          <Textarea rows={3} {...register('description')} />
        </Field>
        <label className="flex items-center gap-3 text-sm text-neutral-800">
          <Switch checked={active} onChange={setActive} label="Ativo" /> Disponível em orçamentos e ordens de serviço
        </label>
      </form>
    </Modal>
  )
}
