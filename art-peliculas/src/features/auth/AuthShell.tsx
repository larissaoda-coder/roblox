import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { Logo } from '@/components/layout/Logo'

const STEPS = [80, 70, 50, 35, 20, 5]

/** Layout das telas de acesso: painel institucional em preto + formulário. */
export function AuthShell({ title, description, children, footer }: { title: string; description?: ReactNode; children: ReactNode; footer?: ReactNode }) {
  return (
    <div className="grid min-h-screen bg-white lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
      <aside className="relative hidden flex-col justify-between overflow-hidden bg-neutral-950 p-10 text-white lg:flex">
        <Link to="/" aria-label="Página inicial">
          <Logo inverted />
        </Link>
        <div>
          <p className="max-w-sm text-[28px] font-semibold leading-tight tracking-tight">
            Cada vidro, o nível certo de película.
          </p>
          <p className="mt-3 max-w-sm text-sm leading-relaxed text-neutral-400">
            Simule, orce e acompanhe os serviços da Art Películas com dados reais e acesso seguro.
          </p>
          <div className="mt-10 flex max-w-sm gap-1.5" aria-hidden="true">
            {STEPS.map((v) => (
              <div key={v} className="flex-1">
                <div className="h-24 rounded-md border border-white/10" style={{ background: `rgba(255,255,255,${(v / 100) * 0.9})` }} />
                <p className="num mt-2 text-center text-[11px] text-neutral-500">{v}%</p>
              </div>
            ))}
          </div>
        </div>
        <p className="text-xs text-neutral-500">© {new Date().getFullYear()} Art Películas</p>
      </aside>
      <main className="flex flex-col items-center justify-center px-5 py-12 sm:px-10">
        <div className="w-full max-w-sm animate-fade-in">
          <Link to="/" className="mb-10 inline-block lg:hidden" aria-label="Página inicial">
            <Logo />
          </Link>
          <h1 className="text-2xl font-semibold tracking-tight text-neutral-950">{title}</h1>
          {description && <p className="mt-1.5 text-sm text-neutral-500">{description}</p>}
          <div className="mt-8">{children}</div>
          {footer && <div className="mt-8 text-center text-sm text-neutral-500">{footer}</div>}
        </div>
      </main>
    </div>
  )
}
