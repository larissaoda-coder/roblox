import { AlertCircle } from 'lucide-react'
import { Button, EmptyState } from '@/components/ui'
import { toMessage } from '@/lib/errors'

export function ErrorState({ error, onRetry, className }: { error: unknown; onRetry?: () => void; className?: string }) {
  return (
    <EmptyState
      icon={AlertCircle}
      title="Não foi possível carregar os dados"
      description={toMessage(error)}
      className={className}
      action={
        onRetry && (
          <Button variant="secondary" onClick={onRetry}>
            Tentar novamente
          </Button>
        )
      }
    />
  )
}
