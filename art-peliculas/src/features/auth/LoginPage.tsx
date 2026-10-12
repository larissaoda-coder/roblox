import { useEffect, useState } from 'react'
import { Link, Navigate, useLocation, useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useQueryClient } from '@tanstack/react-query'
import { Button, Field, FormError, FormSuccess, Input, PasswordInput } from '@/components/ui'
import { useAuth } from '@/auth/AuthProvider'
import { supabase } from '@/lib/supabase'
import { toMessage } from '@/lib/errors'
import { emailSchema } from '@/lib/validation'
import { AuthShell } from './AuthShell'

const schema = z.object({
  email: emailSchema,
  password: z.string().min(1, 'Informe a senha.'),
})
type FormValues = z.infer<typeof schema>

export function LoginPage() {
  const { session, initializing, profile } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const queryClient = useQueryClient()
  const state = location.state as { from?: string; message?: string } | null
  const [formError, setFormError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(state?.message ?? null)

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { email: '', password: '' } })

  useEffect(() => {
    document.title = 'Entrar · Art Películas'
  }, [])

  if (!initializing && session && profile?.active && !isSubmitting) {
    return <Navigate to={state?.from ?? '/app'} replace />
  }

  const onSubmit = async (values: FormValues) => {
    setFormError(null)
    setSuccess(null)
    const { data, error } = await supabase.auth.signInWithPassword({ email: values.email.trim(), password: values.password })
    if (error || !data.user) {
      setFormError(toMessage(error, 'Não foi possível entrar. Tente novamente.'))
      return
    }
    const { data: me, error: meError } = await supabase.from('profiles').select('active').eq('id', data.user.id).maybeSingle()
    if (meError || !me?.active) {
      await supabase.auth.signOut()
      setFormError(meError ? toMessage(meError) : 'Sua conta ainda não foi liberada ou está desativada. Fale com o administrador.')
      return
    }
    await queryClient.invalidateQueries({ queryKey: ['me'] })
    setSuccess('Acesso autorizado. Redirecionando…')
    navigate(state?.from ?? '/app', { replace: true })
  }

  return (
    <AuthShell
      title="Entrar"
      description="Acesse o painel com o seu e-mail e senha."
      footer={
        <>
          Não tem acesso? Solicite um convite ao administrador.
          <br />
          <Link to="/" className="mt-2 inline-block font-medium text-neutral-900 underline-offset-4 hover:underline">
            Voltar ao início
          </Link>
        </>
      }
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        <FormError message={formError} />
        <FormSuccess message={success} />
        <Field label="E-mail" error={errors.email?.message}>
          <Input type="email" autoComplete="email" placeholder="voce@artpeliculas.com.br" {...register('email')} />
        </Field>
        <Field label="Senha" error={errors.password?.message}>
          <PasswordInput autoComplete="current-password" placeholder="••••••••" {...register('password')} />
        </Field>
        <div className="flex justify-end">
          <Link to="/recuperar-senha" className="text-[13px] font-medium text-neutral-700 underline-offset-4 hover:text-neutral-950 hover:underline">
            Esqueci minha senha
          </Link>
        </div>
        <Button type="submit" size="lg" className="w-full" loading={isSubmitting}>
          {isSubmitting ? 'Entrando…' : 'Entrar'}
        </Button>
      </form>
    </AuthShell>
  )
}
