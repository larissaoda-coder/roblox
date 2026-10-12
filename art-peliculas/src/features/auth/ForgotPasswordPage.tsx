import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button, Field, FormError, FormSuccess, Input } from '@/components/ui'
import { supabase } from '@/lib/supabase'
import { toMessage } from '@/lib/errors'
import { emailSchema } from '@/lib/validation'
import { AuthShell } from './AuthShell'

const schema = z.object({ email: emailSchema })
type FormValues = z.infer<typeof schema>

export function ForgotPasswordPage() {
  const [formError, setFormError] = useState<string | null>(null)
  const [sent, setSent] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { email: '' } })

  useEffect(() => {
    document.title = 'Recuperar senha · Art Películas'
  }, [])

  const onSubmit = async ({ email }: FormValues) => {
    setFormError(null)
    setSent(null)
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/redefinir-senha`,
    })
    if (error) {
      setFormError(toMessage(error, 'Não foi possível enviar o e-mail. Tente novamente.'))
      return
    }
    // Mensagem neutra: não revela se o e-mail possui conta.
    setSent('Se houver uma conta com este e-mail, você receberá em instantes um link para criar uma nova senha.')
  }

  return (
    <AuthShell
      title="Recuperar senha"
      description="Informe o e-mail da sua conta para receber o link de redefinição."
      footer={
        <Link to="/entrar" className="font-medium text-neutral-900 underline-offset-4 hover:underline">
          Voltar para o login
        </Link>
      }
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        <FormError message={formError} />
        <FormSuccess message={sent} />
        <Field label="E-mail" error={errors.email?.message}>
          <Input type="email" autoComplete="email" placeholder="voce@artpeliculas.com.br" {...register('email')} />
        </Field>
        <Button type="submit" size="lg" className="w-full" loading={isSubmitting}>
          {isSubmitting ? 'Enviando…' : 'Enviar link de redefinição'}
        </Button>
      </form>
    </AuthShell>
  )
}
