import { beforeAll, describe, expect, it } from 'vitest'
import { anon, createUser, enabled, env, extractLink, service, signIn, uid, waitForEmail, type TestUser } from './helpers'

// PNG 1x1 transparente
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64')

describe.skipIf(!enabled)('armazenamento de mídias', () => {
  let vendedor: TestUser
  let gerente: TestUser
  let vehicleId: string

  beforeAll(async () => {
    ;[vendedor, gerente] = await Promise.all([createUser('vendedor'), createUser('gerente')])
    const { data } = await gerente.client.from('vehicles').insert({ brand: 'Teste', model: `Armazenamento ${uid()}`, category: 'hatch' }).select().single()
    vehicleId = data!.id
  })

  it('somente quem gerencia a garagem envia imagens de veículos', async () => {
    const path = `vehicles/${vehicleId}/${uid()}.png`
    const denied = await vendedor.client.storage.from('media').upload(path, PNG, { contentType: 'image/png' })
    expect(denied.error).not.toBeNull()
    const ok = await gerente.client.storage.from('media').upload(path, PNG, { contentType: 'image/png' })
    expect(ok.error).toBeNull()

    // Usuários ativos visualizam por URL assinada; visitantes não.
    const signed = await vendedor.client.storage.from('media').createSignedUrl(path, 60)
    expect(signed.error).toBeNull()
    const res = await fetch(signed.data!.signedUrl)
    expect(res.status).toBe(200)
    const publicTry = await anon().storage.from('media').download(path)
    expect(publicTry.error).not.toBeNull()

    // Vendedor não remove a mídia.
    const del = await vendedor.client.storage.from('media').remove([path])
    expect(del.data ?? []).toHaveLength(0)
    const delOk = await gerente.client.storage.from('media').remove([path])
    expect(delOk.data).toHaveLength(1)
  })

  it('pastas fora das áreas previstas são recusadas', async () => {
    const { error } = await gerente.client.storage.from('media').upload(`outros/${uid()}.png`, PNG, { contentType: 'image/png' })
    expect(error).not.toBeNull()
  })

  it('o logotipo exige permissão de configurações', async () => {
    const v = await vendedor.client.storage.from('media').upload(`branding/${uid()}.png`, PNG, { contentType: 'image/png' })
    expect(v.error).not.toBeNull()
  })
})

describe.skipIf(!enabled)('administração de usuários (Edge Function)', () => {
  let admin: TestUser
  let vendedor: TestUser

  beforeAll(async () => {
    ;[admin, vendedor] = await Promise.all([createUser('admin'), createUser('vendedor')])
  })

  it('recusa quem não gerencia usuários', async () => {
    const { error } = await vendedor.client.functions.invoke('admin-users', { body: { action: 'create', email: `x-${uid()}@artpeliculas.test`, full_name: 'X', role: 'admin', password: 'Senha-12345' } })
    expect(error).not.toBeNull()
    const body = await (error as { context: Response }).context.json()
    expect(body.error).toContain('não tem permissão')
  })

  it('valida os dados enviados', async () => {
    const { error } = await admin.client.functions.invoke('admin-users', { body: { action: 'create', email: 'invalido', full_name: 'X', role: 'vendedor', password: '123' } })
    const body = await (error as { context: Response }).context.json()
    expect(body.error).toContain('e-mail válido')
  })

  it('cria, desativa e reativa contas', async () => {
    const email = `novo-${uid()}@artpeliculas.test`
    const password = `Senha-${uid()}9`
    const { data, error } = await admin.client.functions.invoke('admin-users', { body: { action: 'create', email, full_name: 'Nina Nova', role: 'instalador', password } })
    expect(error).toBeNull()
    const id = (data as { id: string }).id

    const { data: profile } = await service().from('profiles').select('role, active, full_name').eq('id', id).single()
    expect(profile).toEqual({ role: 'instalador', active: true, full_name: 'Nina Nova' })
    expect((await signIn(email, password)).error).toBeNull()

    const off = await admin.client.functions.invoke('admin-users', { body: { action: 'set_active', user_id: id, active: false } })
    expect(off.error).toBeNull()
    const blocked = await signIn(email, password)
    expect(blocked.error?.message).toMatch(/banned/i)

    const on = await admin.client.functions.invoke('admin-users', { body: { action: 'set_active', user_id: id, active: true } })
    expect(on.error).toBeNull()
    expect((await signIn(email, password)).error).toBeNull()

    // O histórico registra o administrador que alterou o perfil.
    const { data: log } = await service().from('audit_log').select('changed_by, new_data').eq('table_name', 'profiles').eq('record_id', id).order('id')
    expect(log!.some((l) => l.changed_by === admin.id && (l.new_data as { active?: boolean }).active === false)).toBe(true)
  })

  it('administrador não desativa a própria conta', async () => {
    const { error } = await admin.client.functions.invoke('admin-users', { body: { action: 'set_active', user_id: admin.id, active: false } })
    const body = await (error as { context: Response }).context.json()
    expect(body.error).toContain('própria conta')
  })

  it.skipIf(!env.mailpit)('envia convite por e-mail e o convidado define a senha', async () => {
    const email = `convite-${uid()}@artpeliculas.test`
    const { error } = await admin.client.functions.invoke('admin-users', {
      body: { action: 'invite', email, full_name: 'Carla Convidada', role: 'vendedor' },
      headers: { origin: 'http://localhost:5173' },
    })
    expect(error).toBeNull()
    const mail = await waitForEmail(email, 'convidado')
    const link = extractLink(mail.HTML)
    expect(decodeURIComponent(link)).toContain('redirect_to=http://localhost:5173/redefinir-senha')

    const res = await fetch(link, { redirect: 'manual' })
    const location = res.headers.get('location') ?? ''
    expect(location).toContain('/redefinir-senha#access_token=')
    const token = new URLSearchParams(location.split('#')[1]).get('access_token')!
    const client = anon()
    const { error: setErr } = await client.auth.setSession({ access_token: token, refresh_token: new URLSearchParams(location.split('#')[1]).get('refresh_token')! })
    expect(setErr).toBeNull()
    const { error: upd } = await client.auth.updateUser({ password: 'Nova-Senha-123' })
    expect(upd).toBeNull()
    expect((await signIn(email, 'Nova-Senha-123')).error).toBeNull()
  })

  it.skipIf(!env.mailpit)('recuperação de senha por e-mail', async () => {
    const u = await createUser('vendedor')
    const { error } = await anon().auth.resetPasswordForEmail(u.email, { redirectTo: 'http://localhost:5173/redefinir-senha' })
    expect(error).toBeNull()
    const mail = await waitForEmail(u.email, 'Redefinição de senha')
    expect(mail.HTML).toContain('Criar nova senha')
    const res = await fetch(extractLink(mail.HTML), { redirect: 'manual' })
    const hash = new URLSearchParams((res.headers.get('location') ?? '').split('#')[1])
    expect(hash.get('type')).toBe('recovery')
    const client = anon()
    await client.auth.setSession({ access_token: hash.get('access_token')!, refresh_token: hash.get('refresh_token')! })
    expect((await client.auth.updateUser({ password: 'Recuperada-123' })).error).toBeNull()
    expect((await signIn(u.email, u.password)).error).not.toBeNull()
    expect((await signIn(u.email, 'Recuperada-123')).error).toBeNull()
  })
})
