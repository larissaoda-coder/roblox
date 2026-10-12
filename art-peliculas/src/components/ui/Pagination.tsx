import { ChevronLeft, ChevronRight } from 'lucide-react'
import { Button } from './Button'

export function Pagination({
  page,
  pageSize,
  total,
  onPageChange,
}: {
  page: number
  pageSize: number
  total: number
  onPageChange: (page: number) => void
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize))
  if (total <= pageSize) {
    return total > 0 ? <p className="px-4 py-3 text-xs text-neutral-500">{total} {total === 1 ? 'registro' : 'registros'}</p> : null
  }
  const from = (page - 1) * pageSize + 1
  const to = Math.min(total, page * pageSize)
  return (
    <div className="flex items-center justify-between gap-3 border-t border-neutral-200 px-4 py-3">
      <p className="text-xs text-neutral-500">
        {from}–{to} de {total}
      </p>
      <div className="flex items-center gap-1">
        <Button variant="ghost" size="icon-sm" onClick={() => onPageChange(page - 1)} disabled={page <= 1} aria-label="Página anterior">
          <ChevronLeft className="h-4 w-4" />
        </Button>
        <span className="px-2 text-xs text-neutral-600 num">
          {page} / {pages}
        </span>
        <Button variant="ghost" size="icon-sm" onClick={() => onPageChange(page + 1)} disabled={page >= pages} aria-label="Próxima página">
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>
    </div>
  )
}
