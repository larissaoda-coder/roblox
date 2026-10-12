import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { anon, createUser, enabled, randomCpf, service, uid, type TestUser } from './helpers'

describe.skipIf(!enabled)('segurança: acesso anônimo', () => {
  it('visitantes não leem nenhuma tabela', async () => {
    const client = anon()
    for (const table of ['vehicles', 'customers', 'profiles', 'settings', 'quotes', 'films', 'audit_log']) {
      const { data, error } = await client.from(table).select('*').limit(1)
      expect(error?.code, table).toBe('42501')
      expect(data).toBeNull()
    }
  })

  it('visitantes não executam funções do sistema', async () => {
    const { error } = await anon().rpc('save_quote', { p_quote: {} })
    expect(error).not.toBeNull()
    const stats = await anon().rpc('dashboard_stats')
    expect(stats.error).not.toBeNull()
  })

  it('cadastro público está desativado', async () => {
    const { error } = await anon().auth.signUp({ email: `intruso-${uid()}@artpeliculas.test`, password: 'Senha-12345' })
    expect(error).not.toBeNull()
  })
})

describe.skipIf(!enabled)('segurança: papéis e permissões (RLS)', () => {
  let vendedor: TestUser
  let gerente: TestUser
  let inativo: TestUser
  let instalador: TestUser

  beforeAll(async () => {
    ;[vendedor, gerente, inativo, instalador] = await Promise.all([
      createUser('vendedor'),
      createUser('gerente'),
      createUser('vendedor', { active: false }),
      createUser('instalador'),
    ])
  })

  afterAll(async () => {
    // Mantém o banco de desenvolvimento limpo de contas de teste.
    const admin = service()
    for (const u of [inativo, instalador]) if (u) await admin.auth.admin.deleteUser(u.id)
  })

  it('usuário inativo não lê nem grava dados', async () => {
    const { data } = await inativo.client.from('vehicles').select('id').limit(5)
    expect(data).toEqual([])
    const { error } = await inativo.client.from('customers').insert({ name: 'Não deveria' })
    expect(error?.code).toBe('42501')
    const { data: perms } = await inativo.client.rpc('my_permissions')
    expect(perms).toEqual([])
  })

  it('vendedor cadastra clientes mas não exclui', async () => {
    const { data: c, error } = await vendedor.client.from('customers').insert({ name: `Cliente ${uid()}` }).select().single()
    expect(error).toBeNull()
    const { data: deleted } = await vendedor.client.from('customers').delete().eq('id', c!.id).select('id')
    expect(deleted).toEqual([])
    const { data: still } = await gerente.client.from('customers').select('id').eq('id', c!.id)
    expect(still).toHaveLength(1)
  })

  it('vendedor não altera garagem, catálogo, configurações nem permissões', async () => {
    const v = await vendedor.client.from('vehicles').insert({ brand: 'Teste', model: uid(), category: 'hatch' })
    expect(v.error?.code).toBe('42501')
    const f = await vendedor.client.from('films').insert({ name: uid(), manufacturer: 'X', vlt_percent: 20, price: 10 })
    expect(f.error?.code).toBe('42501')
    const s = await vendedor.client.from('settings').update({ max_discount_percent: 100 }).eq('id', 1).select()
    expect(s.data).toEqual([])
    const rp = await vendedor.client.from('role_permissions').insert({ role: 'vendedor', permission: 'orcamentos.desconto_livre' })
    expect(rp.error?.code).toBe('42501')
  })

  it('vendedor não promove a si mesmo nem altera o e-mail do perfil', async () => {
    const role = await vendedor.client.from('profiles').update({ role: 'admin' }).eq('id', vendedor.id).select()
    expect(role.error?.code).toBe('42501')
    const email = await vendedor.client.from('profiles').update({ email: 'outro@x.com' } as never).eq('id', vendedor.id)
    expect(email.error?.code).toBe('42501')
    const ok = await vendedor.client.from('profiles').update({ full_name: 'Vendedor Renomeado' }).eq('id', vendedor.id).select()
    expect(ok.data).toHaveLength(1)
  })

  it('vendedor não grava orçamentos fora das funções do servidor', async () => {
    const { data: c } = await vendedor.client.from('customers').insert({ name: `Cliente ${uid()}` }).select().single()
    const direct = await vendedor.client.from('quotes').insert({ customer_id: c!.id, total: 1 })
    expect(direct.error?.code).toBe('42501')
    const items = await vendedor.client.from('quote_items').insert({ quote_id: c!.id, kind: 'outro', description: 'x', quantity: 1, unit_price: 1, total: 1 })
    expect(items.error?.code).toBe('42501')
  })

  it('histórico só é visível com permissão', async () => {
    const v = await vendedor.client.from('audit_log').select('id').limit(1)
    expect(v.data).toEqual([])
    const g = await gerente.client.from('audit_log').select('id').limit(1)
    expect(g.data?.length).toBe(1)
  })

  it('somente administradores gerenciam usuários', async () => {
    const r = await gerente.client.rpc('list_users')
    expect(r.error?.code).toBe('42501')
    const role = await gerente.client.from('profiles').update({ role: 'admin' }).eq('id', vendedor.id).select()
    expect(role.error ?? role.data?.length === 0).toBeTruthy()
  })

  it('instalador só gerencia serviços', async () => {
    const { data: perms } = await instalador.client.rpc('my_permissions')
    expect(perms).toEqual(['servicos.gerenciar'])
    const c = await instalador.client.from('customers').insert({ name: 'X' })
    expect(c.error?.code).toBe('42501')
  })

  it('o banco valida CPF/CNPJ e impede duplicidade', async () => {
    const bad = await vendedor.client.from('customers').insert({ name: 'Doc inválido', document: '52998224724' })
    expect(bad.error?.code).toBe('23514')
    const cnpj = await vendedor.client.from('customers').insert({ name: 'Empresa Alfa', document: `12.ABC.345/01DE-35` }).select().single()
    // O CNPJ de exemplo pode já existir de execuções anteriores.
    expect(cnpj.error === null || cnpj.error.code === '23505').toBe(true)
    const cpf = randomCpf()
    const first = await vendedor.client.from('customers').insert({ name: 'Doc 1', document: cpf })
    expect(first.error).toBeNull()
    const dup = await vendedor.client.from('customers').insert({ name: 'Doc 2', document: cpf.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4') })
    expect(dup.error?.code).toBe('23505')
  })

  it('o sistema nunca fica sem administrador ativo', async () => {
    const { error } = await service().from('profiles').update({ active: false }).eq('role', 'admin')
    expect(error?.message).toContain('administrador ativo')
  })
})
