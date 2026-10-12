import { useLayoutEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button, Combobox, Field, FormError, Input, Modal, Select, Textarea, useToast } from '@/components/ui'
import { ROLE_LABELS, SERVICE_STATUSES, SERVICE_STATUS_LABELS } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import { formatDocument, formatPlate, normalizePlate, quoteCode, vehicleName } from '@/lib/format'
import { useDebounced } from '@/lib/hooks'
import { decimalField, optionalPlate, toNullableNumber } from '@/lib/validation'
import type { ServiceOrder, ServiceOrderStatus } from '@/types/domain'
import { useCustomerOptions } from '@/features/customers/api'
import { useVehicles } from '@/features/vehicles/api'
import { useSaveServiceOrder, useServiceTypes, useTeam } from './api'

const schema = z.object({
  customer_id: z.string().min(1, 'Selecione o cliente.'),
  vehicle_id: z.string().nullable(),
  vehicle_description: z.string().max(160),
  vehicle_plate: optionalPlate,
  service_type_id: z.string(),
  description: z.string().trim().min(2, 'Descreva o serviço.').max(500, 'Máximo de 500 caracteres.'),
  status: z.enum(['agendado', 'em_andamento', 'concluido', 'cancelado']),
  scheduled_at: z.string(),
  assigned_to: z.string(),
  price: decimalField({ min: 0, required: false }),
  notes: z.string().max(2000, 'Máximo de 2000 caracteres.'),
})
type FormValues = z.infer<typeof schema>

export interface ServiceOrderPrefill {
  quote_id?: string | null
  quote_number?: number | null
  customer_id?: string
  customer_name?: string
  vehicle_id?: string | null
  vehicle_description?: string
  vehicle_plate?: string | null
  description?: string
  price?: number | null
}

/** Converte ISO (UTC) para o valor de <input type="datetime-local"> no fuso local. */
function toLocalInput(iso: string | null | undefined) {
  if (!iso) return ''
  const d = new Date(iso)
  const off = d.getTimezoneOffset()
  return new Date(d.getTime() - off * 60000).toISOString().slice(0, 16)
}

export function ServiceOrderFormModal({
  open,
  onClose,
  order,
  prefill,
  onSaved,
}: {
  open: boolean
  onClose: () => void
  order?: (ServiceOrder & { customer?: { name: string } | null }) | null
  prefill?: ServiceOrderPrefill
  onSaved?: (o: ServiceOrder) => void
}) {
  const save = useSaveServiceOrder()
  const toast = useToast()
  const team = useTeam()
  const types = useServiceTypes()
  const vehicles = useVehicles()
  const [search, setSearch] = useState('')
  const customers = useCustomerOptions(useDebounced(search))
  const [customerLabel, setCustomerLabel] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  const defaults = (): FormValues => ({
    customer_id: order?.customer_id ?? prefill?.customer_id ?? '',
    vehicle_id: order?.vehicle_id ?? prefill?.vehicle_id ?? null,
    vehicle_description: order?.vehicle_description ?? prefill?.vehicle_description ?? '',
    vehicle_plate: formatPlate(order?.vehicle_plate ?? prefill?.vehicle_plate ?? ''),
    service_type_id: order?.service_type_id ?? '',
    description: order?.description ?? prefill?.description ?? '',
    status: order?.status ?? 'agendado',
    scheduled_at: toLocalInput(order?.scheduled_at),
    assigned_to: order?.assigned_to ?? '',
    price: order?.price != null ? String(order.price).replace('.', ',') : prefill?.price != null ? String(prefill.price).replace('.', ',') : '',
    notes: order?.notes ?? '',
  })

  const {
    register,
    control,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: defaults() })

  // Reinicia o formulário somente ao abrir (prefill pode ser recriado a cada renderização do pai).
  useLayoutEffect(() => {
    if (open) {
      reset(defaults())
      setCustomerLabel(order?.customer?.name ?? prefill?.customer_name ?? '')
      setFormError(null)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, order?.id])

  const vehicleId = watch('vehicle_id')
  const quoteId = order?.quote_id ?? prefill?.quote_id ?? null

  const onSubmit = async (v: FormValues) => {
    setFormError(null)
    try {
      const saved = await save.mutateAsync({
        id: order?.id,
        input: {
          quote_id: quoteId,
          customer_id: v.customer_id,
          vehicle_id: v.vehicle_id,
          vehicle_description: v.vehicle_id ? '' : v.vehicle_description.trim(),
          vehicle_plate: v.vehicle_plate.trim() ? normalizePlate(v.vehicle_plate) : null,
          service_type_id: v.service_type_id || null,
          description: v.description.trim(),
          status: v.status as ServiceOrderStatus,
          scheduled_at: v.scheduled_at ? new Date(v.scheduled_at).toISOString() : null,
          assigned_to: v.assigned_to || null,
          price: toNullableNumber(v.price),
          notes: v.notes.trim(),
        },
      })
      toast.success(order ? 'Ordem de serviço atualizada.' : 'Ordem de serviço registrada.')
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
      title={order ? 'Editar ordem de serviço' : 'Nova ordem de serviço'}
      description={quoteId ? (prefill?.quote_number ? `Vinculada ao orçamento ${quoteCode(prefill.quote_number)}` : 'Vinculada a um orçamento') : undefined}
      size="lg"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" form="service-order-form" loading={isSubmitting}>
            {order ? 'Salvar alterações' : 'Registrar serviço'}
          </Button>
        </>
      }
    >
      <form id="service-order-form" onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
        <FormError message={formError} />
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Cliente" required error={errors.customer_id?.message} className="sm:col-span-2">
            <Controller
              control={control}
              name="customer_id"
              render={({ field }) => (
                <Combobox
                  value={field.value || null}
                  selectedLabel={customerLabel}
                  onChange={(v, opt) => {
                    field.onChange(v ?? '')
                    setCustomerLabel(opt?.label ?? '')
                  }}
                  onSearchChange={setSearch}
                  loading={customers.isFetching}
                  options={(customers.data ?? []).map((c) => ({ value: c.id, label: c.name, description: c.document ? formatDocument(c.document) : undefined }))}
                  placeholder="Buscar cliente"
                  disabled={Boolean(quoteId)}
                />
              )}
            />
          </Field>
          <Field label="Veículo" className="sm:col-span-2">
            <Controller
              control={control}
              name="vehicle_id"
              render={({ field }) => (
                <Combobox
                  value={field.value}
                  onChange={(v) => field.onChange(v)}
                  options={(vehicles.data ?? []).map((v) => ({ value: v.id, label: vehicleName(v) }))}
                  placeholder="Buscar na garagem"
                />
              )}
            />
          </Field>
          {!vehicleId && (
            <Field label="Descrição do veículo" className="sm:col-span-2">
              <Input {...register('vehicle_description')} />
            </Field>
          )}
          <Field label="Placa" error={errors.vehicle_plate?.message}>
            <Input className="uppercase" {...register('vehicle_plate')} />
          </Field>
          <Field label="Tipo de serviço">
            <Select
              {...register('service_type_id', {
                onChange: (e) => {
                  const st = types.data?.find((t) => t.id === e.target.value)
                  if (st && !watch('description')) setValue('description', st.name)
                },
              })}
            >
              <option value="">Não especificado</option>
              {(types.data ?? []).map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Descrição do serviço" required error={errors.description?.message} className="sm:col-span-2">
            <Textarea rows={2} {...register('description')} />
          </Field>
          <Field label="Data e hora" error={errors.scheduled_at?.message}>
            <Input type="datetime-local" {...register('scheduled_at')} />
          </Field>
          <Field label="Situação">
            <Select {...register('status')}>
              {SERVICE_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {SERVICE_STATUS_LABELS[s]}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Responsável">
            <Select {...register('assigned_to')}>
              <option value="">Não definido</option>
              {(team.data ?? [])
                .filter((p) => p.active)
                .map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.full_name} ({ROLE_LABELS[p.role]})
                  </option>
                ))}
            </Select>
          </Field>
          <Field label="Valor (R$)" error={errors.price?.message}>
            <Input inputMode="decimal" placeholder="0,00" {...register('price')} />
          </Field>
        </div>
        <Field label="Observações" error={errors.notes?.message}>
          <Textarea rows={3} {...register('notes')} />
        </Field>
      </form>
    </Modal>
  )
}

