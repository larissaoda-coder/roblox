import { useLayoutEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Search } from 'lucide-react'
import { Button, Field, FormError, Input, Modal, Select, Textarea, useToast } from '@/components/ui'
import { BR_STATES } from '@/lib/constants'
import { toMessage } from '@/lib/errors'
import { formatDocument, formatPhone, formatZip, onlyDigits } from '@/lib/format'
import { optionalDocument, optionalEmail, optionalPhone } from '@/lib/validation'
import type { Customer } from '@/types/domain'
import { useSaveCustomer } from './api'

const schema = z.object({
  name: z.string().trim().min(2, 'Informe o nome (mínimo de 2 caracteres).').max(120, 'Máximo de 120 caracteres.'),
  document: optionalDocument,
  email: optionalEmail,
  phone: optionalPhone,
  zip_code: z
    .string()
    .trim()
    .refine((v) => v === '' || onlyDigits(v).length === 8, 'CEP inválido.'),
  street: z.string().max(160),
  address_number: z.string().max(20),
  complement: z.string().max(80),
  district: z.string().max(80),
  city: z.string().max(80),
  state: z.string(),
  notes: z.string().max(2000, 'Máximo de 2000 caracteres.'),
})
type FormValues = z.infer<typeof schema>

function defaults(c?: Customer | null): FormValues {
  return {
    name: c?.name ?? '',
    document: formatDocument(c?.document),
    email: c?.email ?? '',
    phone: formatPhone(c?.phone),
    zip_code: formatZip(c?.zip_code),
    street: c?.street ?? '',
    address_number: c?.address_number ?? '',
    complement: c?.complement ?? '',
    district: c?.district ?? '',
    city: c?.city ?? '',
    state: c?.state ?? '',
    notes: c?.notes ?? '',
  }
}

export function CustomerFormModal({
  open,
  onClose,
  customer,
  onSaved,
}: {
  open: boolean
  onClose: () => void
  customer?: Customer | null
  onSaved?: (c: Customer) => void
}) {
  const save = useSaveCustomer()
  const toast = useToast()
  const [formError, setFormError] = useState<string | null>(null)
  const [cepLoading, setCepLoading] = useState(false)
  const {
    register,
    handleSubmit,
    reset,
    setValue,
    getValues,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: defaults(customer) })

  useLayoutEffect(() => {
    if (open) {
      reset(defaults(customer))
      setFormError(null)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, customer?.id])

  // Preenche o endereço a partir do CEP (serviço público ViaCEP).
  const lookupCep = async () => {
    const cep = onlyDigits(getValues('zip_code'))
    if (cep.length !== 8) return
    setCepLoading(true)
    try {
      const res = await fetch(`https://viacep.com.br/ws/${cep}/json/`)
      const data = (await res.json()) as { erro?: boolean; logradouro?: string; bairro?: string; localidade?: string; uf?: string }
      if (data.erro) {
        toast.info('CEP não encontrado. Preencha o endereço manualmente.')
        return
      }
      if (data.logradouro) setValue('street', data.logradouro)
      if (data.bairro) setValue('district', data.bairro)
      if (data.localidade) setValue('city', data.localidade)
      if (data.uf) setValue('state', data.uf)
    } catch {
      toast.info('Não foi possível consultar o CEP agora. Preencha o endereço manualmente.')
    } finally {
      setCepLoading(false)
    }
  }

  const onSubmit = async (v: FormValues) => {
    setFormError(null)
    try {
      const saved = await save.mutateAsync({
        id: customer?.id,
        input: {
          name: v.name.trim(),
          document: v.document.trim() || null,
          email: v.email.trim() || null,
          phone: v.phone.trim() || null,
          zip_code: v.zip_code.trim() || null,
          street: v.street.trim(),
          address_number: v.address_number.trim(),
          complement: v.complement.trim(),
          district: v.district.trim(),
          city: v.city.trim(),
          state: v.state || null,
          notes: v.notes.trim(),
        },
      })
      toast.success(customer ? 'Cliente atualizado.' : 'Cliente cadastrado.')
      onSaved?.(saved)
      onClose()
    } catch (err) {
      setFormError(toMessage(err))
    }
  }

  const docReg = register('document')
  const phoneReg = register('phone')
  const zipReg = register('zip_code')

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={customer ? 'Editar cliente' : 'Novo cliente'}
      size="lg"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" form="customer-form" loading={isSubmitting}>
            {customer ? 'Salvar alterações' : 'Cadastrar cliente'}
          </Button>
        </>
      }
    >
      <form id="customer-form" onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        <FormError message={formError} />
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Nome completo ou razão social" required error={errors.name?.message} className="sm:col-span-2">
            <Input autoComplete="off" {...register('name')} />
          </Field>
          <Field label="CPF ou CNPJ" error={errors.document?.message}>
            <Input
              inputMode="text"
              placeholder="000.000.000-00"
              {...docReg}
              onBlur={(e) => {
                void docReg.onBlur(e)
                setValue('document', formatDocument(e.target.value), { shouldValidate: true })
              }}
            />
          </Field>
          <Field label="Telefone / WhatsApp" error={errors.phone?.message}>
            <Input
              inputMode="tel"
              placeholder="(00) 00000-0000"
              {...phoneReg}
              onBlur={(e) => {
                void phoneReg.onBlur(e)
                setValue('phone', formatPhone(e.target.value), { shouldValidate: true })
              }}
            />
          </Field>
          <Field label="E-mail" error={errors.email?.message} className="sm:col-span-2">
            <Input type="email" autoComplete="off" {...register('email')} />
          </Field>
        </div>

        <div>
          <p className="eyebrow mb-3">Endereço</p>
          <div className="grid gap-4 sm:grid-cols-6">
            <Field label="CEP" error={errors.zip_code?.message} className="sm:col-span-2">
              <div className="flex gap-1.5">
                <Input
                  inputMode="numeric"
                  placeholder="00000-000"
                  {...zipReg}
                  onBlur={(e) => {
                    void zipReg.onBlur(e)
                    setValue('zip_code', formatZip(e.target.value), { shouldValidate: true })
                    void lookupCep()
                  }}
                />
                <Button variant="secondary" size="icon" aria-label="Buscar CEP" onClick={lookupCep} loading={cepLoading}>
                  {!cepLoading && <Search className="h-4 w-4" />}
                </Button>
              </div>
            </Field>
            <Field label="Logradouro" className="sm:col-span-4">
              <Input {...register('street')} />
            </Field>
            <Field label="Número" className="sm:col-span-1">
              <Input {...register('address_number')} />
            </Field>
            <Field label="Complemento" className="sm:col-span-2">
              <Input {...register('complement')} />
            </Field>
            <Field label="Bairro" className="sm:col-span-3">
              <Input {...register('district')} />
            </Field>
            <Field label="Cidade" className="sm:col-span-4">
              <Input {...register('city')} />
            </Field>
            <Field label="UF" className="sm:col-span-2">
              <Select {...register('state')}>
                <option value="">—</option>
                {BR_STATES.map((uf) => (
                  <option key={uf} value={uf}>
                    {uf}
                  </option>
                ))}
              </Select>
            </Field>
          </div>
        </div>

        <Field label="Observações" error={errors.notes?.message}>
          <Textarea rows={3} {...register('notes')} />
        </Field>
      </form>
    </Modal>
  )
}
