import { randomUUID } from 'node:crypto'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'

/**
 * Testes de integração contra um projeto Supabase de DESENVOLVIMENTO (nunca produção).
 * Variáveis: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY e, opcionalmente,
 * MAILPIT_URL (caixa de e-mails de teste do Supabase local).
 */
export const env = {
  url: process.env.SUPABASE_URL ?? '',
  anon: process.env.SUPABASE_ANON_KEY ?? '',
  service: process.env.SUPABASE_SERVICE_ROLE_KEY ?? '',
  mailpit: process.env.MAILPIT_URL ?? '',
}
export const enabled = Boolean(env.url && env.anon && env.service)

const opts = { auth: { persistSession: false, autoRefreshToken: false } }

export const service = () => createClient(env.url, env.service, opts)
export const anon = () => createClient(env.url, env.anon, opts)

export type Role = 'admin' | 'gerente' | 'vendedor' | 'instalador'

export interface TestUser {
  id: string
  email: string
  password: string
  client: SupabaseClient
}

export const uid = () => randomUUID().slice(0, 8)

export async function createUser(role: Role, { active = true, name }: { active?: boolean; name?: string } = {}): Promise<TestUser> {
  const admin = service()
  const email = `teste-${role}-${uid()}@artpeliculas.test`
  const password = `Senha-${uid()}1`
  const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name: name ?? `Teste ${role}` } })
  if (error) throw error
  const id = data.user.id
  const { error: pErr } = await admin.from('profiles').update({ role, active }).eq('id', id)
  if (pErr) throw pErr
  const client = anon()
  const { error: sErr } = await client.auth.signInWithPassword({ email, password })
  if (sErr) throw sErr
  return { id, email, password, client }
}

export async function signIn(email: string, password: string) {
  const client = anon()
  const { error } = await client.auth.signInWithPassword({ email, password })
  return { client, error }
}

/** CPF válido gerado aleatoriamente (somente para testes). */
export function randomCpf() {
  const n = Array.from({ length: 9 }, () => Math.floor(Math.random() * 10))
  const dv = (digits: number[]) => {
    const s = digits.reduce((acc, d, i) => acc + d * (digits.length + 1 - i), 0)
    const r = (s * 10) % 11
    return r === 10 ? 0 : r
  }
  const d1 = dv(n)
  const d2 = dv([...n, d1])
  return [...n, d1, d2].join('')
}

export interface MailMessage {
  ID: string
  Subject: string
  To: Array<{ Address: string }>
}

/** Aguarda um e-mail para o destinatário no Mailpit e retorna o HTML. */
export async function waitForEmail(to: string, subjectIncludes: string, timeoutMs = 15000) {
  const end = Date.now() + timeoutMs
  while (Date.now() < end) {
    const res = await fetch(`${env.mailpit}/api/v1/search?query=${encodeURIComponent(`to:${to}`)}`)
    const data = (await res.json()) as { messages: MailMessage[] }
    const msg = data.messages.find((m) => m.Subject.includes(subjectIncludes))
    if (msg) {
      const full = (await (await fetch(`${env.mailpit}/api/v1/message/${msg.ID}`)).json()) as { HTML: string; Text: string }
      return full
    }
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error(`E-mail "${subjectIncludes}" para ${to} não chegou.`)
}

export function extractLink(html: string) {
  const m = /href="([^"]*\/auth\/v1\/verify[^"]*)"/.exec(html)
  if (!m) throw new Error('Link de verificação não encontrado no e-mail.')
  return m[1].replace(/&amp;/g, '&')
}
