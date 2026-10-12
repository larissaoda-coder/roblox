import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Controller, useFieldArray, useForm, useWatch } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Info, Layers, Lock, Plus, SunDim, Trash2, UserPlus, Wrench } from 'lucide-react'
import {
  Button,
  Card,
  CardBody,
  CardHeader,
  Combobox,
  EmptyState,
  Field,
  FormError,
  Input,
  PageLoader,
  Segmented,
  Select,
  Textarea,
  useToast,
} from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { supabase } from '@/lib/supabase'
import { toMessage } from '@/lib/errors'
import { ITEM_KIND_LABELS, ZONES, ZONE_SHORT } from '@/lib/constants'
import { checkDiscount, computeQuoteTotals, itemTotal } from '@/lib/quote-calc'
import { formatCurrency, formatDocument, formatPercent, normalizePlate, parseDecimal, quoteCode, todayISO, vehicleName, vehicleYears } from '@/lib/format'
import { decimalField, intField, optionalPlate } from '@/lib/validation'
import { cn } from '@/lib/cn'
import type { GlassZone, QuoteItemKind, Simulation } from '@/types/domain'
import { useCustomerOptions } from '@/features/customers/api'
import { CustomerFormModal } from '@/features/customers/CustomerFormModal'
import { filmLabel, useFilms } from '@/features/films/api'
import { useVehicleFilms, useVehicles } from '@/features/vehicles/api'
import { useServiceTypes } from '@/features/services/api'
import { useSettings } from '@/features/settings/api'
import { useDebounced } from '@/lib/hooks'
import { useQuote, useSaveQuote } from './api'
import { filmDescription, filmUnitPrice, itemsFromSimulation, suggestedQuantity, toInput, type EditorItem } from './buildItems'

const itemSchema = z
  .object({
    kind: z.enum(['pelicula', 'servico', 'outro']),
    film_id: z.string().nullable(),
    service_type_id: z.string().nullable(),
    glass_zones: z.array(z.enum(['para_brisa', 'dianteiros', 'traseiros', 'vidro_traseiro'])),
    description: z.string().trim().min(1, 'Informe a descrição.').max(300, 'Máximo de 300 caracteres.'),
    quantity: decimalField({ min: 0.01, max: 99999, label: 'a quantidade' }),
    unit_price: decimalField({ min: 0, max: 9999999, label: 'o valor unitário' }),
    discount: decimalField({ min: 0, required: false }),
  })
  .refine((i) => !i.discount || parseDecimal(i.discount) <= parseDecimal(i.quantity) * parseDecimal(i.unit_price) + 0.001, {
    path: ['discount'],
    message: 'Maior que o valor do item.',
  })

const schema = z.object({
  customer_id: z.string({ invalid_type_error: 'Selecione o cliente.' }).min(1, 'Selecione o cliente.'),
  vehicle_id: z.string().nullable(),
  vehicle_description: z.string().max(160),
  vehicle_plate: optionalPlate,
  vehicle_year: intField({ required: false, min: 1950, max: new Date().getFullYear() + 2 }),
  vehicle_color: z.string().max(40, 'Máximo de 40 caracteres.'),
  simulation_id: z.string().nullable(),
  valid_until: z.string().min(1, 'Informe a validade.'),
  discount_type: z.enum(['valor', 'percentual']),
  discount_value: decimalField({ min: 0, required: false }),
  notes: z.string().max(4000, 'Máximo de 4000 caracteres.'),
  internal_notes: z.string().max(4000, 'Máximo de 4000 caracteres.'),
  items: z.array(itemSchema).min(1, 'Adicione pelo menos um item.').max(100, 'Máximo de 100 itens.'),
})
type FormValues = z.infer<typeof schema>

function addDays(iso: string, days: number) {
  const [y, m, d] = iso.split('-').map(Number)
  const dt = new Date(y, m - 1, d + days)
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`
}

const blankItem = (kind: QuoteItemKind): EditorItem => ({
  kind,
  film_id: null,
  service_type_id: null,
  glass_zones: [],
  description: '',
  quantity: '1',
  unit_price: '',
  discount: '',
})

export function QuoteEditorPage() {
  const { id } = useParams()
  const [params] = useSearchParams()
  const navigate = useNavigate()
  const toast = useToast()
  const { can } = useAuth()
  const isEdit = Boolean(id)
  const simulationParam = params.get('simulacao')
  const customerParam = params.get('cliente')

  const existing = useQuote(id)
  const settings = useSettings()
  const films = useFilms()
  const vehicles = useVehicles()
  const serviceTypes = useServiceTypes()
  const save = useSaveQuote()
  const simulation = useQuery({
    queryKey: ['simulations', 'detail', simulationParam],
    enabled: Boolean(simulationParam) && !isEdit,
    queryFn: async () => {
      const { data, error } = await supabase.from('simulations').select('*').eq('id', simulationParam!).maybeSingle()
      if (error) throw error
      return data as Simulation | null
    },
  })

  const [customerSearch, setCustomerSearch] = useState('')
  const debouncedSearch = useDebounced(customerSearch)
  const customerOptions = useCustomerOptions(debouncedSearch)
  const [customerLabel, setCustomerLabel] = useState('')
  const [creatingCustomer, setCreatingCustomer] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      customer_id: customerParam ?? '',
      vehicle_id: null,
      vehicle_description: '',
      vehicle_plate: '',
      vehicle_year: '',
      vehicle_color: '',
      simulation_id: null,
      valid_until: addDays(todayISO(), 15),
      discount_type: 'valor',
      discount_value: '',
      notes: '',
      internal_notes: '',
      items: [],
    },
  })
  const { register, control, handleSubmit, reset, setValue, getValues, formState } = form
  const { errors, isSubmitting } = formState
  const items = useFieldArray({ control, name: 'items' })
  const watched = useWatch({ control })
  const vehicleId = watched.vehicle_id ?? null
  const vehicleFilms = useVehicleFilms(vehicleId ?? undefined)
  const overrides = useMemo(() => new Map((vehicleFilms.data ?? []).map((r) => [r.film_id, r.price_override])), [vehicleFilms.data])
  const activeFilms = useMemo(() => (films.data ?? []).filter((f) => f.active), [films.data])

  // Carrega orçamento existente
  const loaded = useRef(false)
  useEffect(() => {
    const q = existing.data
    if (!q || loaded.current) return
    loaded.current = true
    setCustomerLabel(q.customer?.name ?? '')
    reset({
      customer_id: q.customer_id,
      vehicle_id: q.vehicle_id,
      vehicle_description: q.vehicle_description,
      vehicle_plate: q.vehicle_plate ?? '',
      vehicle_year: q.vehicle_year?.toString() ?? '',
      vehicle_color: q.vehicle_color,
      simulation_id: q.simulation_id,
      valid_until: q.valid_until ?? addDays(todayISO(), 15),
      discount_type: q.discount_type,
      discount_value: q.discount_value ? toInput(q.discount_value) : '',
      notes: q.notes,
      internal_notes: q.internal_notes,
      items: q.quote_items.map((i) => ({
        kind: i.kind,
        film_id: i.film_id,
        service_type_id: i.service_type_id,
        glass_zones: i.glass_zones,
        description: i.description,
        quantity: toInput(i.quantity),
        unit_price: toInput(i.unit_price),
        discount: i.discount ? toInput(i.discount) : '',
      })),
    })
  }, [existing.data, reset])

  // Validade padrão e termos das configurações (somente em novos orçamentos)
  const settingsApplied = useRef(false)
  useEffect(() => {
    if (isEdit || !settings.data || settingsApplied.current) return
    settingsApplied.current = true
    setValue('valid_until', addDays(todayISO(), settings.data.quote_validity_days))
    if (!getValues('notes') && settings.data.quote_terms) setValue('notes', settings.data.quote_terms)
  }, [isEdit, settings.data, setValue, getValues])

  // Pré-preenchimento a partir de uma simulação salva
  const simApplied = useRef(false)
  useEffect(() => {
    const sim = simulation.data
    if (isEdit || !sim || !films.data || simApplied.current) return
    simApplied.current = true
    setValue('simulation_id', sim.id)
    setValue('vehicle_id', sim.vehicle_id)
    if (sim.customer_id) setValue('customer_id', sim.customer_id)
    void supabase
      .from('vehicle_films')
      .select('film_id, price_override')
      .eq('vehicle_id', sim.vehicle_id)
      .then(({ data }) => {
        const map = new Map((data ?? []).map((r) => [r.film_id as string, r.price_override as number | null]))
        items.replace(itemsFromSimulation(sim.config, films.data!, map))
      })
  }, [simulation.data, films.data, isEdit, setValue, items])

  // Garante rótulo do cliente pré-selecionado
  const presetCustomer = watched.customer_id
  useEffect(() => {
    if (!presetCustomer || customerLabel) return
    void supabase
      .from('customers')
      .select('name')
      .eq('id', presetCustomer)
      .maybeSingle()
      .then(({ data }) => data && setCustomerLabel(data.name as string))
  }, [presetCustomer, customerLabel])

  const totals = computeQuoteTotals(
    (watched.items ?? []).map((i) => ({
      quantity: parseDecimal(i?.quantity ?? '') || 0,
      unit_price: parseDecimal(i?.unit_price ?? '') || 0,
      discount: parseDecimal(i?.discount ?? '') || 0,
    })),
    watched.discount_type ?? 'valor',
    parseDecimal(watched.discount_value ?? '') || 0,
  )
  const maxDiscount = settings.data?.max_discount_percent ?? 0
  const canExceed = can('orcamentos.desconto_livre')
  const discountCheck = checkDiscount(totals, {
    maxPercent: maxDiscount,
    canExceed,
    authorizedPercent: existing.data?.discount_authorized_percent ?? null,
  })

  if (!can('orcamentos.gerenciar')) {
    return <EmptyState icon={Lock} title="Acesso restrito" description="Seu papel não permite criar ou editar orçamentos." className="py-24" />
  }
  if ((isEdit && existing.isLoading) || films.isLoading || vehicles.isLoading) return <PageLoader />
  if (isEdit && !existing.data) return <EmptyState title="Orçamento não encontrado" className="py-24" />
  if (existing.data && ['aprovado', 'concluido'].includes(existing.data.status)) {
    return (
      <EmptyState
        icon={Lock}
        title="Orçamento bloqueado para edição"
        description="Orçamentos aprovados ou concluídos não podem ser alterados. Volte o status para rascunho na página do orçamento para editar."
        action={
          <Link to={`/app/orcamentos/${id}`} className="inline-flex h-10 items-center rounded-md bg-neutral-950 px-4 text-sm font-medium text-white">
            Voltar ao orçamento
          </Link>
        }
        className="py-24"
      />
    )
  }

  const vehicle = vehicles.data?.find((v) => v.id === vehicleId) ?? null

  const onSubmit = async (v: FormValues) => {
    setFormError(null)
    if (!discountCheck.ok) {
      setFormError(discountCheck.message ?? 'Desconto inválido.')
      return
    }
    try {
      const savedId = await save.mutateAsync({
        id,
        customer_id: v.customer_id,
        vehicle_id: v.vehicle_id,
        vehicle_description: v.vehicle_id ? '' : v.vehicle_description.trim(),
        vehicle_plate: v.vehicle_plate.trim() ? normalizePlate(v.vehicle_plate) : null,
        vehicle_year: v.vehicle_year.trim() ? Number(v.vehicle_year) : null,
        vehicle_color: v.vehicle_color.trim(),
        simulation_id: v.simulation_id,
        valid_until: v.valid_until,
        discount_type: v.discount_type,
        discount_value: parseDecimal(v.discount_value) || 0,
        notes: v.notes,
        internal_notes: v.internal_notes,
        items: v.items.map((i) => ({
          kind: i.kind,
          film_id: i.kind === 'pelicula' ? i.film_id : null,
          service_type_id: i.kind === 'servico' ? i.service_type_id : null,
          glass_zones: i.kind === 'pelicula' ? i.glass_zones : [],
          description: i.description.trim(),
          quantity: parseDecimal(i.quantity),
          unit_price: parseDecimal(i.unit_price),
          discount: parseDecimal(i.discount) || 0,
        })),
      })
      toast.success(isEdit ? 'Orçamento atualizado.' : 'Orçamento criado.')
      navigate(`/app/orcamentos/${savedId}`, { replace: true })
    } catch (err) {
      setFormError(toMessage(err))
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  const setItemFilm = (index: number, filmId: string) => {
    const film = activeFilms.find((f) => f.id === filmId) ?? films.data?.find((f) => f.id === filmId)
    const current = getValues(`items.${index}`)
    if (!film) {
      setValue(`items.${index}.film_id`, null)
      return
    }
    const zones = current.glass_zones
    items.update(index, {
      ...current,
      film_id: film.id,
      description: filmDescription(film, zones),
      unit_price: toInput(filmUnitPrice(film, overrides)),
      quantity: toInput(suggestedQuantity(film, zones)),
    })
  }

  const toggleZone = (index: number, zone: GlassZone) => {
    const current = getValues(`items.${index}`)
    const zones = current.glass_zones.includes(zone) ? current.glass_zones.filter((z) => z !== zone) : [...current.glass_zones, zone]
    const film = current.film_id ? films.data?.find((f) => f.id === current.film_id) : undefined
    items.update(index, {
      ...current,
      glass_zones: zones,
      ...(film ? { description: filmDescription(film, zones), quantity: toInput(suggestedQuantity(film, zones)) } : {}),
    })
  }

  const setItemService = (index: number, serviceId: string) => {
    const st = serviceTypes.data?.find((s) => s.id === serviceId)
    const current = getValues(`items.${index}`)
    if (!st) return setValue(`items.${index}.service_type_id`, null)
    items.update(index, { ...current, service_type_id: st.id, description: st.name, unit_price: toInput(st.base_price) })
  }

  const customerOpts = (customerOptions.data ?? []).map((c) => ({
    value: c.id,
    label: c.name,
    description: [c.document ? formatDocument(c.document) : null, c.city].filter(Boolean).join(' · ') || undefined,
  }))

  return (
    <>
      <PageHeader
        backTo={isEdit ? `/app/orcamentos/${id}` : '/app/orcamentos'}
        backLabel={isEdit ? 'Voltar ao orçamento' : 'Orçamentos'}
        title={isEdit ? `Editar ${quoteCode(existing.data?.number)}` : 'Novo orçamento'}
        description="Os totais e o limite de desconto são validados novamente pelo servidor ao salvar."
      />

      <form onSubmit={handleSubmit(onSubmit)} noValidate className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_340px]">
        <div className="min-w-0 space-y-6">
          <FormError message={formError} />

          <Card>
            <CardHeader title="Cliente e veículo" />
            <CardBody className="grid gap-4 sm:grid-cols-2">
              <Field label="Cliente" required error={errors.customer_id?.message} className="sm:col-span-2">
                <div className="flex gap-2">
                  <Controller
                    control={control}
                    name="customer_id"
                    render={({ field }) => (
                      <Combobox
                        className="flex-1"
                        value={field.value || null}
                        selectedLabel={customerLabel}
                        onChange={(v, opt) => {
                          field.onChange(v ?? '')
                          setCustomerLabel(opt?.label ?? '')
                        }}
                        onSearchChange={setCustomerSearch}
                        loading={customerOptions.isFetching}
                        options={customerOpts}
                        placeholder="Buscar cliente por nome, CPF/CNPJ ou telefone"
                        aria-invalid={Boolean(errors.customer_id)}
                      />
                    )}
                  />
                  {can('clientes.gerenciar') && (
                    <Button variant="secondary" icon={<UserPlus className="h-4 w-4" />} onClick={() => setCreatingCustomer(true)}>
                      <span className="hidden sm:inline">Novo</span>
                    </Button>
                  )}
                </div>
              </Field>
              <Field label="Veículo da garagem" className="sm:col-span-2" hint={vehicle ? undefined : 'Se o veículo não estiver na garagem, descreva-o no campo abaixo.'}>
                <Controller
                  control={control}
                  name="vehicle_id"
                  render={({ field }) => (
                    <Combobox
                      value={field.value}
                      onChange={(v) => field.onChange(v)}
                      options={(vehicles.data ?? []).map((v) => ({ value: v.id, label: vehicleName(v), description: vehicleYears(v) }))}
                      placeholder="Buscar marca, modelo ou geração"
                    />
                  )}
                />
              </Field>
              {!vehicle && (
                <Field label="Descrição do veículo" error={errors.vehicle_description?.message} className="sm:col-span-2">
                  <Input placeholder="Ex.: Volkswagen Jetta 2015" {...register('vehicle_description')} />
                </Field>
              )}
              <Field label="Placa" error={errors.vehicle_plate?.message}>
                <Input placeholder="ABC1D23" className="uppercase" {...register('vehicle_plate')} />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field label="Ano" error={errors.vehicle_year?.message}>
                  <Input inputMode="numeric" {...register('vehicle_year')} />
                </Field>
                <Field label="Cor" error={errors.vehicle_color?.message}>
                  <Input {...register('vehicle_color')} />
                </Field>
              </div>
              {watched.simulation_id && (
                <div className="flex items-center justify-between gap-3 rounded-md border border-neutral-200 bg-neutral-50 px-3 py-2 text-sm sm:col-span-2">
                  <span className="flex items-center gap-2 text-neutral-700">
                    <SunDim className="h-4 w-4" /> Vinculado a uma simulação salva
                  </span>
                  <span className="flex gap-3">
                    <Link to={`/app/simulador?simulacao=${watched.simulation_id}`} target="_blank" className="text-[13px] font-medium underline-offset-4 hover:underline">
                      Ver
                    </Link>
                    <button type="button" className="text-[13px] text-neutral-500 hover:text-neutral-900" onClick={() => setValue('simulation_id', null)}>
                      Desvincular
                    </button>
                  </span>
                </div>
              )}
            </CardBody>
          </Card>

          <Card>
            <CardHeader
              title="Itens"
              description="Películas, serviços e outros itens com valores individuais."
              actions={
                <>
                  <Button size="sm" variant="secondary" icon={<Layers className="h-3.5 w-3.5" />} onClick={() => items.append(blankItem('pelicula'))}>
                    Película
                  </Button>
                  <Button size="sm" variant="secondary" icon={<Wrench className="h-3.5 w-3.5" />} onClick={() => items.append(blankItem('servico'))}>
                    Serviço
                  </Button>
                  <Button size="sm" variant="ghost" icon={<Plus className="h-3.5 w-3.5" />} onClick={() => items.append(blankItem('outro'))}>
                    Outro
                  </Button>
                </>
              }
            />
            {items.fields.length === 0 ? (
              <EmptyState
                icon={Layers}
                title="Nenhum item adicionado"
                description={errors.items?.message ?? errors.items?.root?.message ?? 'Adicione películas, serviços ou outros itens.'}
              />
            ) : (
              <ul className="divide-y divide-neutral-200">
                {items.fields.map((field, index) => {
                  const it = watched.items?.[index]
                  const kind = it?.kind ?? field.kind
                  const err = errors.items?.[index]
                  const lineTotal = itemTotal({
                    quantity: parseDecimal(it?.quantity ?? '') || 0,
                    unit_price: parseDecimal(it?.unit_price ?? '') || 0,
                    discount: parseDecimal(it?.discount ?? '') || 0,
                  })
                  return (
                    <li key={field.id} className="space-y-3 px-5 py-4" data-testid="quote-item">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="rounded bg-neutral-100 px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-neutral-600">
                          {ITEM_KIND_LABELS[kind]}
                        </span>
                        {kind === 'pelicula' && (
                          <Select
                            aria-label="Película do catálogo"
                            className="h-9 min-w-0 flex-1 text-[13px]"
                            value={it?.film_id ?? ''}
                            onChange={(e) => setItemFilm(index, e.target.value)}
                          >
                            <option value="">Selecione a película do catálogo…</option>
                            {activeFilms.map((f) => (
                              <option key={f.id} value={f.id}>
                                {filmLabel(f)}
                                {overrides.has(f.id) ? ' (indicada)' : ''}
                              </option>
                            ))}
                          </Select>
                        )}
                        {kind === 'servico' && (
                          <Select
                            aria-label="Tipo de serviço"
                            className="h-9 min-w-0 flex-1 text-[13px]"
                            value={it?.service_type_id ?? ''}
                            onChange={(e) => setItemService(index, e.target.value)}
                          >
                            <option value="">Selecione o tipo de serviço…</option>
                            {(serviceTypes.data ?? [])
                              .filter((s) => s.active || s.id === it?.service_type_id)
                              .map((s) => (
                                <option key={s.id} value={s.id}>
                                  {s.name} — {formatCurrency(s.base_price)}
                                </option>
                              ))}
                          </Select>
                        )}
                        <Button size="icon-sm" variant="ghost" className="ml-auto" aria-label="Remover item" onClick={() => items.remove(index)}>
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                      {kind === 'pelicula' && (
                        <div className="flex flex-wrap gap-1.5" role="group" aria-label="Vidros cobertos">
                          {ZONES.map((z) => {
                            const on = it?.glass_zones?.includes(z) ?? false
                            return (
                              <button
                                key={z}
                                type="button"
                                aria-pressed={on}
                                onClick={() => toggleZone(index, z)}
                                className={cn(
                                  'h-7 rounded-full border px-3 text-xs font-medium transition-colors',
                                  on ? 'border-neutral-950 bg-neutral-950 text-white' : 'border-neutral-300 text-neutral-600 hover:border-neutral-500',
                                )}
                              >
                                {ZONE_SHORT[z]}
                              </button>
                            )
                          })}
                        </div>
                      )}
                      <Field error={err?.description?.message}>
                        <Input aria-label="Descrição do item" placeholder="Descrição" {...register(`items.${index}.description`)} />
                      </Field>
                      <div className="grid grid-cols-2 gap-3 sm:grid-cols-[1fr_1.3fr_1.2fr_1.3fr]">
                        <Field label="Qtd." error={err?.quantity?.message}>
                          <Input inputMode="decimal" {...register(`items.${index}.quantity`)} />
                        </Field>
                        <Field label="Valor unit. (R$)" error={err?.unit_price?.message}>
                          <Input inputMode="decimal" placeholder="0,00" {...register(`items.${index}.unit_price`)} />
                        </Field>
                        <Field label="Desconto (R$)" error={err?.discount?.message}>
                          <Input inputMode="decimal" placeholder="0,00" {...register(`items.${index}.discount`)} />
                        </Field>
                        <div className="space-y-1.5">
                          <p className="text-[13px] font-medium text-neutral-800">Total</p>
                          <p className="flex h-10 items-center justify-end rounded-md bg-neutral-50 px-3 text-sm font-semibold text-neutral-950 num">{formatCurrency(lineTotal)}</p>
                        </div>
                      </div>
                    </li>
                  )
                })}
              </ul>
            )}
          </Card>

          <Card>
            <CardHeader title="Observações" />
            <CardBody className="grid gap-4 md:grid-cols-2">
              <Field label="Observações e condições (impressas)" error={errors.notes?.message}>
                <Textarea rows={5} {...register('notes')} />
              </Field>
              <Field label="Anotações internas (não impressas)" error={errors.internal_notes?.message}>
                <Textarea rows={5} {...register('internal_notes')} />
              </Field>
            </CardBody>
          </Card>
        </div>

        <aside className="space-y-4 xl:sticky xl:top-24 xl:self-start">
          <Card>
            <CardHeader title="Resumo" />
            <CardBody className="space-y-4">
              <dl className="space-y-2 text-sm">
                <Row label="Subtotal" value={formatCurrency(totals.subtotal)} />
                <Row label="Descontos nos itens" value={`− ${formatCurrency(totals.itemsDiscount)}`} />
                <Row label="Desconto no orçamento" value={`− ${formatCurrency(totals.quoteDiscount)}`} />
                <div className="border-t border-neutral-200 pt-2">
                  <Row label="Total" value={formatCurrency(totals.total)} strong />
                </div>
              </dl>
              <div className="space-y-2">
                <p className="text-[13px] font-medium text-neutral-800">Desconto geral</p>
                <Controller
                  control={control}
                  name="discount_type"
                  render={({ field }) => (
                    <Segmented
                      size="sm"
                      ariaLabel="Tipo de desconto"
                      value={field.value}
                      onChange={field.onChange}
                      items={[
                        { value: 'valor', label: 'R$' },
                        { value: 'percentual', label: '%' },
                      ]}
                    />
                  )}
                />
                <Field error={errors.discount_value?.message}>
                  <Input inputMode="decimal" placeholder="0" aria-label="Valor do desconto" {...register('discount_value')} />
                </Field>
                <p className={cn('flex items-start gap-1.5 text-xs', discountCheck.ok ? 'text-neutral-500' : 'font-medium text-neutral-950')}>
                  <Info className="mt-px h-3.5 w-3.5 shrink-0" />
                  {discountCheck.ok
                    ? `Desconto total: ${formatPercent(Math.round(totals.discountPercent * 100) / 100)}. ${canExceed ? 'Você pode autorizar descontos acima do limite.' : `Seu limite: ${formatPercent(maxDiscount)}.`}`
                    : discountCheck.message}
                </p>
              </div>
              <Field label="Válido até" required error={errors.valid_until?.message}>
                <Input type="date" {...register('valid_until')} />
              </Field>
              <Button type="submit" size="lg" className="w-full" loading={isSubmitting}>
                {isEdit ? 'Salvar alterações' : 'Criar orçamento'}
              </Button>
              {errors.items?.message && <p className="text-xs font-medium text-neutral-950">{errors.items.message}</p>}
            </CardBody>
          </Card>
        </aside>
      </form>

      <CustomerFormModal
        open={creatingCustomer}
        onClose={() => setCreatingCustomer(false)}
        onSaved={(c) => {
          setValue('customer_id', c.id, { shouldValidate: true })
          setCustomerLabel(c.name)
        }}
      />
    </>
  )
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <dt className={strong ? 'font-semibold text-neutral-950' : 'text-neutral-600'}>{label}</dt>
      <dd className={cn('num', strong ? 'text-lg font-semibold text-neutral-950' : 'text-neutral-900')}>{value}</dd>
    </div>
  )
}

