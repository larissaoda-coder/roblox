import { Logo } from '@/components/layout/Logo'

/** Exibida quando as variáveis de ambiente do Supabase não foram configuradas. */
export function SetupRequired() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-neutral-50 px-4">
      <div className="w-full max-w-lg rounded-2xl border border-neutral-200 bg-white p-8 shadow-soft">
        <Logo />
        <h1 className="mt-8 text-xl font-semibold text-neutral-950">Configuração pendente</h1>
        <p className="mt-2 text-sm leading-relaxed text-neutral-600">
          Defina as variáveis <code className="rounded bg-neutral-100 px-1.5 py-0.5 text-[13px]">VITE_SUPABASE_URL</code> e{' '}
          <code className="rounded bg-neutral-100 px-1.5 py-0.5 text-[13px]">VITE_SUPABASE_ANON_KEY</code> no arquivo{' '}
          <code className="rounded bg-neutral-100 px-1.5 py-0.5 text-[13px]">.env</code> (veja <code>.env.example</code>) e reinicie a aplicação.
        </p>
      </div>
    </div>
  )
}
