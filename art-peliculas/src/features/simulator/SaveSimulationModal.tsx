import { useLayoutEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, Combobox, Field, FormError, Modal, Textarea } from '@/components/ui'
import { supabase } from '@/lib/supabase'
import { toMessage } from '@/lib/errors'
import { formatDocument } from '@/lib/format'
import { useDebounced } from '@/lib/hooks'
import type { Simulation, SimulationConfig, SimulationMode } from '@/types/domain'
import { useCustomerOptions } from '@/features/customers/api'

export interface SimulationDraft {
  vehicle_id: string
  vehicle_image_id: string | null
  mode: SimulationMode
  config: SimulationConfig
}

export function useCreateSimulation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (input: SimulationDraft & { customer_id: string | null; notes: string }) => {
      const { data, error } = await supabase.from('simulations').insert(input).select().single()
      if (error) throw error
      return data as Simulation
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['dashboard'] })
      void qc.invalidateQueries({ queryKey: ['simulations'] })
    },
  })
}

export function SaveSimulationModal({
  open,
  onClose,
  draft,
  initialCustomerId,
  onSaved,
}: {
  open: boolean
  onClose: () => void
  draft: SimulationDraft | null
  initialCustomerId?: string | null
  onSaved: (sim: Simulation) => void
}) {
  const [search, setSearch] = useState('')
  const [customerId, setCustomerId] = useState<string | null>(initialCustomerId ?? null)
  const [customerLabel, setCustomerLabel] = useState('')
  const [notes, setNotes] = useState('')
  const [error, setError] = useState<string | null>(null)
  const customers = useCustomerOptions(useDebounced(search))
  const create = useCreateSimulation()

  useLayoutEffect(() => {
    if (open) {
      setError(null)
      setNotes('')
      setCustomerId(initialCustomerId ?? null)
    }
  }, [open, initialCustomerId])

  const submit = async () => {
    if (!draft) return
    setError(null)
    try {
      const sim = await create.mutateAsync({ ...draft, customer_id: customerId, notes: notes.trim() })
      onSaved(sim)
    } catch (err) {
      setError(toMessage(err))
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Salvar simulação"
      description="A simulação fica registrada e pode gerar um orçamento."
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button onClick={submit} loading={create.isPending}>
            Salvar simulação
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <FormError message={error} />
        <Field label="Cliente (opcional)">
          <Combobox
            value={customerId}
            selectedLabel={customerLabel}
            onChange={(v, opt) => {
              setCustomerId(v)
              setCustomerLabel(opt?.label ?? '')
            }}
            onSearchChange={setSearch}
            loading={customers.isFetching}
            options={(customers.data ?? []).map((c) => ({
              value: c.id,
              label: c.name,
              description: [c.document ? formatDocument(c.document) : null, c.city].filter(Boolean).join(' · ') || undefined,
            }))}
            placeholder="Buscar cliente por nome, CPF/CNPJ ou telefone"
            emptyText="Nenhum cliente encontrado."
          />
        </Field>
        <Field label="Observações (opcional)">
          <Textarea rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} maxLength={1000} placeholder="Ex.: cliente preferiu 35% nas laterais." />
        </Field>
      </div>
    </Modal>
  )
}
