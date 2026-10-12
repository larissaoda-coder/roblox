import type { ReactNode } from 'react'
import { cn } from '@/lib/cn'
import { Skeleton } from './Spinner'

export interface Column<T> {
  key: string
  header: ReactNode
  cell: (row: T) => ReactNode
  className?: string
  headerClassName?: string
  align?: 'left' | 'right' | 'center'
}

interface DataTableProps<T> {
  columns: Column<T>[]
  rows: T[] | undefined
  rowKey: (row: T) => string
  loading?: boolean
  empty?: ReactNode
  onRowClick?: (row: T) => void
  /** Renderização em cartões para telas pequenas. */
  mobileCard?: (row: T) => ReactNode
  className?: string
  caption?: string
}

export function DataTable<T>({ columns, rows, rowKey, loading, empty, onRowClick, mobileCard, className, caption }: DataTableProps<T>) {
  if (loading) {
    return (
      <div className="space-y-2 p-4" aria-busy="true">
        {Array.from({ length: 5 }).map((_, i) => (
          <Skeleton key={i} className="h-11 w-full" />
        ))}
      </div>
    )
  }
  if (!rows || rows.length === 0) return <>{empty}</>

  const alignClass = (a?: Column<T>['align']) => (a === 'right' ? 'text-right' : a === 'center' ? 'text-center' : 'text-left')

  return (
    <div className={className}>
      {mobileCard && (
        <ul className="divide-y divide-neutral-200 md:hidden">
          {rows.map((row) => (
            <li key={rowKey(row)}>
              {onRowClick ? (
                <button type="button" onClick={() => onRowClick(row)} className="block w-full px-4 py-3.5 text-left transition-colors hover:bg-neutral-50">
                  {mobileCard(row)}
                </button>
              ) : (
                <div className="px-4 py-3.5">{mobileCard(row)}</div>
              )}
            </li>
          ))}
        </ul>
      )}
      <div className={cn('scrollbar-thin relative overflow-x-auto', mobileCard && 'hidden md:block')}>
        <table className="w-full min-w-[640px] border-collapse text-sm">
          {caption && <caption className="sr-only">{caption}</caption>}
          <thead>
            <tr className="border-b border-neutral-200 bg-neutral-50/80">
              {columns.map((col) => (
                <th
                  key={col.key}
                  scope="col"
                  className={cn('whitespace-nowrap px-4 py-2.5 text-[11.5px] font-semibold uppercase tracking-wide text-neutral-500', alignClass(col.align), col.headerClassName)}
                >
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100">
            {rows.map((row) => (
              <tr
                key={rowKey(row)}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                onKeyDown={
                  onRowClick
                    ? (e) => {
                        if (e.key === 'Enter') onRowClick(row)
                      }
                    : undefined
                }
                tabIndex={onRowClick ? 0 : undefined}
                className={cn('transition-colors', onRowClick && 'cursor-pointer hover:bg-neutral-50 focus-visible:bg-neutral-50 focus-visible:ring-0')}
              >
                {columns.map((col) => (
                  <td key={col.key} className={cn('px-4 py-3 align-middle text-neutral-800', alignClass(col.align), col.className)}>
                    {col.cell(row)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
