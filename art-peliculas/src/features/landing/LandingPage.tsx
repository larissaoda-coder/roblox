import { useEffect } from 'react'
import { Link } from 'react-router-dom'
import { ArrowRight, Car, FileText, Layers, ShieldCheck, SunDim, Wrench } from 'lucide-react'
import { useAuth } from '@/auth/AuthProvider'
import { TintIllustration } from './TintIllustration'

const FEATURES = [
  {
    icon: Car,
    title: 'Garagem virtual',
    text: 'Biblioteca de veículos populares no Brasil, com marca, geração, categoria, imagens autorizadas e modelos 3D.',
  },
  {
    icon: SunDim,
    title: 'Simulador de películas',
    text: 'Aplique níveis de transmissão por vidro — para-brisa, dianteiros, traseiros e vigia — e compare com o original.',
  },
  {
    icon: Layers,
    title: 'Catálogo técnico',
    text: 'Películas com fabricante, transmissão luminosa, características informadas e preço de referência.',
  },
  {
    icon: FileText,
    title: 'Orçamentos completos',
    text: 'Itens, descontos autorizados, validade, impressão e acompanhamento do status até a aprovação.',
  },
  {
    icon: Wrench,
    title: 'Serviços e agenda',
    text: 'Ordens de serviço geradas a partir do orçamento aprovado, com responsável, data e situação.',
  },
  {
    icon: ShieldCheck,
    title: 'Acesso seguro',
    text: 'Contas individuais, papéis com permissões configuráveis e histórico das alterações relevantes.',
  },
]

const STEPS = [
  { n: '01', title: 'Escolha o veículo', text: 'Selecione marca, modelo e geração na garagem virtual.' },
  { n: '02', title: 'Simule os níveis', text: 'Defina a película de cada vidro e compare antes e depois.' },
  { n: '03', title: 'Gere o orçamento', text: 'Transforme a simulação em orçamento e acompanhe o serviço.' },
]

export function LandingPage() {
  const { session } = useAuth()
  useEffect(() => {
    document.title = 'Art Películas — Simulação e gestão de películas automotivas'
  }, [])

  return (
    <>
      <section className="relative overflow-hidden">
        <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 pb-16 pt-14 sm:px-6 lg:grid-cols-[1.05fr_1fr] lg:pb-24 lg:pt-20">
          <div className="animate-fade-in">
            <p className="eyebrow mb-5">Sistema Art Películas</p>
            <h1 className="text-[34px] font-semibold leading-[1.08] tracking-tight text-neutral-950 sm:text-5xl">
              Simulação, orçamento e gestão de películas automotivas.
            </h1>
            <p className="mt-5 max-w-xl text-base leading-relaxed text-neutral-600 sm:text-lg">
              Mostre ao cliente como cada nível de película fica no veículo, gere o orçamento em minutos e acompanhe cada serviço até a entrega.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Link
                to={session ? '/app' : '/entrar'}
                className="inline-flex h-11 items-center justify-center gap-2 rounded-lg bg-neutral-950 px-5 text-[15px] font-medium text-white shadow-soft transition-colors hover:bg-neutral-800"
              >
                {session ? 'Acessar o painel' : 'Entrar no sistema'} <ArrowRight className="h-4 w-4" />
              </Link>
              <a
                href="#recursos"
                className="inline-flex h-11 items-center justify-center rounded-lg border border-neutral-300 bg-white px-5 text-[15px] font-medium text-neutral-900 transition-colors hover:bg-neutral-50"
              >
                Conhecer os recursos
              </a>
            </div>
          </div>
          <div className="animate-fade-in [animation-delay:120ms]">
            <TintIllustration />
          </div>
        </div>
      </section>

      <section id="recursos" className="scroll-mt-16 border-t border-neutral-200 bg-neutral-50">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 lg:py-20">
          <div className="max-w-2xl">
            <p className="eyebrow mb-3">Recursos</p>
            <h2 className="text-2xl font-semibold tracking-tight text-neutral-950 sm:text-3xl">Tudo o que a loja precisa, do atendimento à instalação.</h2>
          </div>
          <div className="mt-10 grid gap-px overflow-hidden rounded-2xl border border-neutral-200 bg-neutral-200 sm:grid-cols-2 lg:grid-cols-3">
            {FEATURES.map((f) => (
              <div key={f.title} className="group bg-white p-6 transition-colors hover:bg-neutral-50 sm:p-7">
                <f.icon className="h-5 w-5 text-neutral-900" strokeWidth={1.5} />
                <h3 className="mt-4 text-[15px] font-semibold text-neutral-950">{f.title}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-neutral-600">{f.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section id="como-funciona" className="scroll-mt-16">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 lg:py-20">
          <p className="eyebrow mb-3">Como funciona</p>
          <div className="grid gap-8 md:grid-cols-3">
            {STEPS.map((s) => (
              <div key={s.n} className="border-t border-neutral-900 pt-5">
                <p className="num text-sm font-medium text-neutral-400">{s.n}</p>
                <h3 className="mt-2 text-lg font-semibold text-neutral-950">{s.title}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-neutral-600">{s.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="bg-neutral-950">
        <div className="mx-auto flex max-w-6xl flex-col items-start justify-between gap-6 px-4 py-14 sm:px-6 md:flex-row md:items-center">
          <div>
            <h2 className="text-xl font-semibold text-white sm:text-2xl">Acesso exclusivo da equipe Art Películas</h2>
            <p className="mt-1.5 text-sm text-neutral-400">Contas criadas por convite do administrador.</p>
          </div>
          <Link
            to={session ? '/app' : '/entrar'}
            className="inline-flex h-11 items-center gap-2 rounded-lg bg-white px-5 text-[15px] font-medium text-neutral-950 transition-colors hover:bg-neutral-200"
          >
            {session ? 'Acessar o painel' : 'Entrar'} <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
      </section>
    </>
  )
}
