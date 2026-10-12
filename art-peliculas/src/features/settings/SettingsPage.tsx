import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useQueryClient } from '@tanstack/react-query'
import { ImagePlus, Lock, Trash2 } from 'lucide-react'
import { Button, Card, CardBody, CardHeader, Field, FormError, Input, PageLoader, PasswordInput, Textarea, useToast } from '@/components/ui'
import { PageHeader } from '@/components/layout/PageHeader'
import { useAuth } from '@/auth/AuthProvider'
import { supabase } from '@/lib/supabase'
import { ROLE_LABELS } from '@/lib/constants'
import { ensureAffected, toMessage } from '@/lib/errors'
import { formatDocument, formatPhone, onlyDigits, parseDecimal } from '@/lib/format'
import { prepareImage, randomName, removeMedia, uploadMedia, useSignedUrl } from '@/lib/storage'
import { decimalField, intField, optionalDocument, optionalEmail, optionalPhone, passwordSchema } from '@/lib/validation'
import { PasswordRules } from '@/features/auth/ResetPasswordPage'
import { ErrorState } from '@/features/shared/ErrorState'
import { useSaveSettings, useSettings } from './api'

export function SettingsPage() {
  const { can } = useAuth()
  return (
    <>
      <PageHeader title="Configurações" description="Seu perfil, sua senha e os parâmetros da empresa usados em orçamentos e no simulador." />
      <div className="grid gap-6 lg:grid-cols-2">
        <ProfileCard />
        <PasswordCard />
      </div>
      <div className="mt-6">{can('configuracoes.gerenciar') ? <CompanyCard /> : <CompanyReadOnly />}</div>
    </>
  )
}

const profileSchema = z.object({
  full_name: z.string().trim().min(2, 'Informe o nome.').max(120, 'Máximo de 120 caracteres.'),
  phone: optionalPhone,
})

function ProfileCard() {
  const { profile, refreshProfile } = useAuth()
  const toast = useToast()
  const qc = useQueryClient()
  const [error, setError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting, isDirty },
  } = useForm<z.infer<typeof profileSchema>>({ resolver: zodResolver(profileSchema) })

  useEffect(() => {
    if (profile) reset({ full_name: profile.full_name, phone: formatPhone(profile.phone) })
  }, [profile, reset])

  if (!profile) return null

  return (
    <Card>
      <CardHeader title="Meu perfil" description={`${profile.email} · ${ROLE_LABELS[profile.role]}`} />
      <CardBody>
        <form
          noValidate
          className="space-y-4"
          onSubmit={handleSubmit(async (v) => {
            setError(null)
            try {
              const { data, error } = await supabase
                .from('profiles')
                .update({ full_name: v.full_name.trim(), phone: onlyDigits(v.phone) || null })
                .eq('id', profile.id)
                .select('id')
              if (error) throw error
              ensureAffected(data)
              await refreshProfile()
              void qc.invalidateQueries({ queryKey: ['team'] })
              toast.success('Perfil atualizado.')
            } catch (err) {
              setError(toMessage(err))
            }
          })}
        >
          <FormError message={error} />
          <Field label="Nome completo" required error={errors.full_name?.message}>
            <Input {...register('full_name')} />
          </Field>
          <Field label="Telefone" error={errors.phone?.message}>
            <Input inputMode="tel" {...register('phone')} />
          </Field>
          <div className="flex justify-end">
            <Button type="submit" loading={isSubmitting} disabled={!isDirty}>
              Salvar perfil
            </Button>
          </div>
        </form>
      </CardBody>
    </Card>
  )
}

const passwordFormSchema = z
  .object({ current: z.string().min(1, 'Informe a senha atual.'), password: passwordSchema, confirm: z.string() })
  .refine((v) => v.password === v.confirm, { path: ['confirm'], message: 'As senhas não conferem.' })
  .refine((v) => v.password !== v.current, { path: ['password'], message: 'A nova senha deve ser diferente da atual.' })

function PasswordCard() {
  const { profile } = useAuth()
  const toast = useToast()
  const [error, setError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    reset,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<z.infer<typeof passwordFormSchema>>({ resolver: zodResolver(passwordFormSchema), defaultValues: { current: '', password: '', confirm: '' } })

  return (
    <Card>
      <CardHeader title="Alterar senha" description="Por segurança, confirme a senha atual." />
      <CardBody>
        <form
          noValidate
          className="space-y-4"
          onSubmit={handleSubmit(async (v) => {
            setError(null)
            if (!profile) return
            // Confirma a senha atual antes de trocar.
            const { error: authError } = await supabase.auth.signInWithPassword({ email: profile.email, password: v.current })
            if (authError) {
              setError('Senha atual incorreta.')
              return
            }
            const { error } = await supabase.auth.updateUser({ password: v.password })
            if (error) {
              setError(toMessage(error))
              return
            }
            reset()
            toast.success('Senha alterada com sucesso.')
          })}
        >
          <FormError message={error} />
          <Field label="Senha atual" error={errors.current?.message}>
            <PasswordInput autoComplete="current-password" {...register('current')} />
          </Field>
          <Field label="Nova senha" error={errors.password?.message}>
            <PasswordInput autoComplete="new-password" {...register('password')} />
          </Field>
          <PasswordRules value={watch('password') ?? ''} />
          <Field label="Confirme a nova senha" error={errors.confirm?.message}>
            <PasswordInput autoComplete="new-password" {...register('confirm')} />
          </Field>
          <div className="flex justify-end">
            <Button type="submit" loading={isSubmitting}>
              Alterar senha
            </Button>
          </div>
        </form>
      </CardBody>
    </Card>
  )
}

const companySchema = z.object({
  company_name: z.string().trim().min(2, 'Informe o nome.').max(120),
  legal_name: z.string().max(160),
  document: optionalDocument,
  phone: z.string().max(30),
  email: optionalEmail,
  address: z.string().max(300),
  website: z.string().max(160),
  quote_validity_days: intField({ min: 1, max: 365, label: 'a validade' }),
  max_discount_percent: decimalField({ min: 0, max: 100, label: 'o desconto máximo' }),
  quote_terms: z.string().max(4000, 'Máximo de 4000 caracteres.'),
  legal_vlt_windshield: decimalField({ min: 0, max: 100, label: 'o valor' }),
  legal_vlt_front: decimalField({ min: 0, max: 100, label: 'o valor' }),
  legal_vlt_rear: decimalField({ min: 0, max: 100, label: 'o valor' }),
})
type CompanyValues = z.infer<typeof companySchema>
const dec = (n: number) => String(n).replace('.', ',')

function CompanyCard() {
  const { data: s, isLoading, error: loadError, refetch } = useSettings()
  const save = useSaveSettings()
  const toast = useToast()
  const [error, setError] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const { url: logoUrl } = useSignedUrl(s?.logo_path)
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<CompanyValues>({ resolver: zodResolver(companySchema) })

  useEffect(() => {
    if (!s) return
    reset({
      company_name: s.company_name,
      legal_name: s.legal_name,
      document: formatDocument(s.document),
      phone: s.phone,
      email: s.email,
      address: s.address,
      website: s.website,
      quote_validity_days: String(s.quote_validity_days),
      max_discount_percent: dec(s.max_discount_percent),
      quote_terms: s.quote_terms,
      legal_vlt_windshield: dec(s.legal_vlt_windshield),
      legal_vlt_front: dec(s.legal_vlt_front),
      legal_vlt_rear: dec(s.legal_vlt_rear),
    })
  }, [s, reset])

  if (isLoading) return <PageLoader />
  if (loadError || !s) return <ErrorState error={loadError} onRetry={() => void refetch()} />

  const onLogo = async (file: File | undefined) => {
    if (!file) return
    setUploading(true)
    try {
      const prepared = await prepareImage(file, 800)
      const path = `branding/${randomName(prepared.extension)}`
      await uploadMedia(path, prepared.blob, prepared.contentType)
      const previous = s.logo_path
      await save.mutateAsync({ logo_path: path })
      await removeMedia([previous]).catch(() => undefined)
      toast.success('Logotipo atualizado.')
    } catch (err) {
      toast.error(toMessage(err, err instanceof Error ? err.message : undefined))
    } finally {
      setUploading(false)
    }
  }

  return (
    <Card>
      <CardHeader title="Empresa e parâmetros" description="Usados nos orçamentos impressos, nos limites de desconto e no simulador." />
      <CardBody>
        <form
          noValidate
          className="space-y-8"
          onSubmit={handleSubmit(async (v) => {
            setError(null)
            try {
              await save.mutateAsync({
                company_name: v.company_name.trim(),
                legal_name: v.legal_name.trim(),
                document: v.document.trim() || null,
                phone: v.phone.trim(),
                email: v.email.trim(),
                address: v.address.trim(),
                website: v.website.trim(),
                quote_validity_days: Number(v.quote_validity_days),
                max_discount_percent: parseDecimal(v.max_discount_percent),
                quote_terms: v.quote_terms,
                legal_vlt_windshield: parseDecimal(v.legal_vlt_windshield),
                legal_vlt_front: parseDecimal(v.legal_vlt_front),
                legal_vlt_rear: parseDecimal(v.legal_vlt_rear),
              })
              toast.success('Configurações salvas.')
            } catch (err) {
              setError(toMessage(err))
            }
          })}
        >
          <FormError message={error} />
          <section className="grid gap-6 md:grid-cols-[200px_1fr]">
            <div>
              <p className="mb-2 text-[13px] font-medium text-neutral-800">Logotipo</p>
              <div className="flex aspect-[3/2] items-center justify-center overflow-hidden rounded-lg border border-neutral-200 bg-neutral-50">
                {logoUrl ? <img src={logoUrl} alt="Logotipo da empresa" className="max-h-full max-w-full object-contain p-3" /> : <span className="text-xs text-neutral-400">Sem logotipo</span>}
              </div>
              <div className="mt-2 flex gap-1.5">
                <label className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-md border border-neutral-300 bg-white px-3 text-[13px] font-medium hover:bg-neutral-50">
                  <ImagePlus className="h-3.5 w-3.5" /> {uploading ? 'Enviando…' : 'Enviar'}
                  <input type="file" accept="image/png,image/jpeg,image/webp" className="sr-only" disabled={uploading} onChange={(e) => onLogo(e.target.files?.[0])} />
                </label>
                {s.logo_path && (
                  <Button
                    size="icon-sm"
                    variant="ghost"
                    aria-label="Remover logotipo"
                    onClick={async () => {
                      try {
                        const previous = s.logo_path
                        await save.mutateAsync({ logo_path: null })
                        await removeMedia([previous]).catch(() => undefined)
                        toast.success('Logotipo removido.')
                      } catch (err) {
                        toast.error(toMessage(err))
                      }
                    }}
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </Button>
                )}
              </div>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Nome fantasia" required error={errors.company_name?.message}>
                <Input {...register('company_name')} />
              </Field>
              <Field label="Razão social" error={errors.legal_name?.message}>
                <Input {...register('legal_name')} />
              </Field>
              <Field label="CNPJ ou CPF" error={errors.document?.message}>
                <Input {...register('document')} />
              </Field>
              <Field label="Telefone" error={errors.phone?.message}>
                <Input {...register('phone')} />
              </Field>
              <Field label="E-mail" error={errors.email?.message}>
                <Input type="email" {...register('email')} />
              </Field>
              <Field label="Site / Instagram" error={errors.website?.message}>
                <Input {...register('website')} />
              </Field>
              <Field label="Endereço" error={errors.address?.message} className="sm:col-span-2">
                <Input {...register('address')} />
              </Field>
            </div>
          </section>

          <section>
            <p className="eyebrow mb-3">Orçamentos</p>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <Field label="Validade padrão (dias)" required error={errors.quote_validity_days?.message}>
                <Input inputMode="numeric" {...register('quote_validity_days')} />
              </Field>
              <Field label="Desconto máximo sem autorização (%)" required error={errors.max_discount_percent?.message} hint="Acima disso, exige a permissão de autorizar descontos.">
                <Input inputMode="decimal" {...register('max_discount_percent')} />
              </Field>
              <Field label="Condições padrão (impressas em novos orçamentos)" error={errors.quote_terms?.message} className="sm:col-span-2">
                <Textarea rows={4} placeholder="Ex.: Pagamento em até 3x no cartão. Garantia conforme fabricante." {...register('quote_terms')} />
              </Field>
            </div>
          </section>

          <section>
            <p className="eyebrow mb-1">Referências de transmissão luminosa mínima (%)</p>
            <p className="mb-3 text-xs text-neutral-500">
              Exibidas como alerta no simulador. Valores iniciais conforme a regulamentação do CONTRAN para o conjunto vidro + película; confira a legislação vigente.
            </p>
            <div className="grid gap-4 sm:grid-cols-3">
              <Field label="Para-brisa" error={errors.legal_vlt_windshield?.message}>
                <Input inputMode="decimal" {...register('legal_vlt_windshield')} />
              </Field>
              <Field label="Vidros dianteiros" error={errors.legal_vlt_front?.message}>
                <Input inputMode="decimal" {...register('legal_vlt_front')} />
              </Field>
              <Field label="Traseiros e vidro traseiro" error={errors.legal_vlt_rear?.message}>
                <Input inputMode="decimal" {...register('legal_vlt_rear')} />
              </Field>
            </div>
          </section>

          <div className="flex justify-end border-t border-neutral-200 pt-5">
            <Button type="submit" loading={isSubmitting}>
              Salvar configurações
            </Button>
          </div>
        </form>
      </CardBody>
    </Card>
  )
}

function CompanyReadOnly() {
  const { data: s } = useSettings()
  if (!s) return null
  return (
    <Card>
      <CardHeader title="Empresa e parâmetros" description="Somente administradores e gerentes podem alterar estes dados." />
      <CardBody className="grid gap-4 text-sm sm:grid-cols-3">
        <p>
          <span className="block text-xs text-neutral-500">Empresa</span>
          {s.company_name}
        </p>
        <p>
          <span className="block text-xs text-neutral-500">Validade padrão dos orçamentos</span>
          {s.quote_validity_days} dias
        </p>
        <p className="flex items-start gap-2">
          <Lock className="mt-0.5 h-3.5 w-3.5 text-neutral-400" />
          <span>
            <span className="block text-xs text-neutral-500">Seu limite de desconto</span>
            {String(s.max_discount_percent).replace('.', ',')}%
          </span>
        </p>
      </CardBody>
    </Card>
  )
}
