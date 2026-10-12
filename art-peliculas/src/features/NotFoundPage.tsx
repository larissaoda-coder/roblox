import { Link } from 'react-router-dom'
import { Compass } from 'lucide-react'
import { EmptyState } from '@/components/ui'

export function NotFoundPage({ inApp = false }: { inApp?: boolean }) {
  const content = (
    <EmptyState
      icon={Compass}
      title="Página não encontrada"
      description="O endereço acessado não existe ou foi movido."
      action={
        <Link to={inApp ? '/app' : '/'} className="inline-flex h-10 items-center rounded-md bg-neutral-950 px-4 text-sm font-medium text-white hover:bg-neutral-800">
          {inApp ? 'Ir para a visão geral' : 'Ir para o início'}
        </Link>
      }
    />
  )
  if (inApp) return <div className="py-16">{content}</div>
  return <div className="flex min-h-screen items-center justify-center bg-neutral-50 px-4">{content}</div>
}
