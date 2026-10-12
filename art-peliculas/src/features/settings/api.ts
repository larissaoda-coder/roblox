import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ensureAffected } from '@/lib/errors'
import type { LegalLimits } from '@/lib/tint'
import type { Settings } from '@/types/domain'

export function useSettings() {
  return useQuery({
    queryKey: ['settings'],
    queryFn: async () => {
      const { data, error } = await supabase.from('settings').select('*').eq('id', 1).single()
      if (error) throw error
      return data as Settings
    },
    staleTime: 5 * 60_000,
  })
}

export type SettingsInput = Partial<Omit<Settings, 'id' | 'updated_at' | 'updated_by'>>

export function useSaveSettings() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (input: SettingsInput) => {
      const { data, error } = await supabase.from('settings').update(input).eq('id', 1).select()
      if (error) throw error
      return ensureAffected(data)[0] as Settings
    },
    onSuccess: (s) => qc.setQueryData(['settings'], s),
  })
}

export function legalLimitsFrom(s: Settings | undefined): LegalLimits {
  return {
    windshield: s?.legal_vlt_windshield ?? 75,
    front: s?.legal_vlt_front ?? 70,
    rear: s?.legal_vlt_rear ?? 28,
  }
}
