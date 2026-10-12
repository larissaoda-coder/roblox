import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Check, Circle } from 'lucide-react'
import { Button, Field, FormError, FormSuccess, PageLoader, PasswordInput } from '@/components/ui'
import { useAuth } from '@/auth/AuthProvider'
import { initialAuthHash, supabase } from '@/lib/supabase'
import { toMessage } from '@/lib/errors'
import { passwordSchema } from '@/lib/validation'
import { cn } from '@/lib/cn'
import { AuthShell } from './AuthShell'

const schema = z
  .object({ password: passwordSchema, confirm: z.string() })
  .refine((v) => v.password === v.confirm, { path: ['confirm'], message: 'As senhas não conferem.' })
type FormValues = z.infer<typeof schema>

function parseHash(hash: string) {
  const params = new URLSearchParams(hash.replace(/^#/, ''))
  return {
    type: params.get('type'),
    error: params.get('error_description') ?? params.get('error'),
    errorCode: params.get('error_code'),
  }
}

export function PasswordRules({ value }: { value: string }) {
  const rules = [
    { ok: value.length >= 8, label: 'Pelo menos 8 caracteres' },
    { ok: /[A-Za-z]/.test(value), label: 'Contém letras' },
    { ok: /\d/.test(value), label: 'Contém números' },
  ]
  return (
    <ul className="space-y-1" aria-label="Requisitos da senha">
      {rules.map((r) => (
        <li key={r.label} className={cn('flex items-center gap-2 text-xs transition-colors', r.ok ? 'text-neutral-900' : 'text-neutral-400')}>
          {r.ok ? <Check className="h-3.5 w-3.5" strokeWidth={2.5} /> : <Circle className="h-3.5 w-3.5" strokeWidth={1.5} />}
          {r.label}
        </li>
      ))}
    </ul>
  )
}

/** Define uma nova senha a partir do link de recuperação ou do convite enviado por e-mail. */
export function ResetPasswordPage() {
  const { session, initializing } = useAuth()
  const navigate = useNavigate()
  const link = useMemo(() => parseHash(initialAuthHash), [])
  const isInvite = link.type === 'invite'
  const [formError, setFormError] = useState<string | null>(null)
  const [done, setDone] = useState(false)

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { password: '', confirm: '' } })
  const password = watch('password')

  useEffect(() => {
    document.title = `${isInvite ? 'Definir senha' : 'Nova senha'} · Art Películas`
  }, [isInvite])

  const onSubmit = async ({ password }: FormValues) => {
    setFormError(null)
    const { error } = await supabase.auth.updateUser({ password })
    if (error) {
      setFormError(toMessage(error, 'Não foi possível salvar a nova senha.'))
      return
    }
    setDone(true)
    window.setTimeout(() => navigate('/app', { replace: true }), 1600)
  }

  const title = isInvite ? 'Defina a sua senha' : 'Criar nova senha'

  if (initializing) {
    return (
      <AuthShell title={title}>
        <PageLoader label="Validando o link…" />
      </AuthShell>
    )
  }

  if (!session) {
    const message = link.error
      ? toMessage({ message: `${link.error} ${link.errorCode ?? ''}` }, 'O link é inválido ou expirou. Solicite um novo.')
      : 'Abra esta página pelo link enviado ao seu e-mail. Se o link expirou, solicite um novo.'
    return (
      <AuthShell title="Link inválido ou expirado" footer={<Link to="/entrar" className="font-medium text-neutral-900 underline-offset-4 hover:underline">Voltar para o login</Link>}>
        <FormError message={message} />
        <Link
          to="/recuperar-senha"
          className="mt-6 inline-flex h-11 w-full items-center justify-center rounded-lg bg-neutral-950 text-[15px] font-medium text-white hover:bg-neutral-800"
        >
          Solicitar novo link
        </Link>
      </AuthShell>
    )
  }

  return (
    <AuthShell
      title={title}
      description={
        <>
          Conta: <span className="font-medium text-neutral-800">{session.user.email}</span>
        </>
      }
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        <FormError message={formError} />
        <FormSuccess message={done ? 'Senha salva com sucesso. Abrindo o painel…' : null} />
        <Field label="Nova senha" error={errors.password?.message}>
          <PasswordInput autoComplete="new-password" {...register('password')} />
        </Field>
        <PasswordRules value={password} />
        <Field label="Confirme a nova senha" error={errors.confirm?.message}>
          <PasswordInput autoComplete="new-password" {...register('confirm')} />
        </Field>
        <Button type="submit" size="lg" className="w-full" loading={isSubmitting} disabled={done}>
          {isSubmitting ? 'Salvando…' : 'Salvar senha'}
        </Button>
      </form>
    </AuthShell>
  )
}
