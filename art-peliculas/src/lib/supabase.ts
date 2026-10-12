import { createClient } from '@supabase/supabase-js'
import { env } from './env'

/** Fragmento da URL na carga da página (links de convite/recuperação), antes do processamento pelo cliente. */
export const initialAuthHash = typeof window !== 'undefined' ? window.location.hash : ''

/**
 * Cliente único do Supabase (autenticação, banco e armazenamento).
 * Usa somente a chave pública; as regras de acesso são aplicadas no banco (RLS).
 */
export const supabase = createClient(env.supabaseUrl || 'http://localhost', env.supabaseAnonKey || 'missing-key', {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    flowType: 'implicit',
  },
})

export const MEDIA_BUCKET = 'media'
