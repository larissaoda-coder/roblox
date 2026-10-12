import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { createUser, enabled, service, uid, type TestUser } from './helpers'

const item = (unit_price: number, quantity = 1, discount = 0) => ({
  kind: 'outro',
  film_id: null,
  service_type_id: null,
  glass_zones: [],
  description: `Item ${uid()}`,
  quantity,
  unit_price,
  discount,
})

describe.skipIf(!enabled)('regras de negócio: orçamentos', () => {
  let vendedor: TestUser
  let gerente: TestUser
  let customerId: string
  let originalMax = 10

  beforeAll(async () => {
    ;[vendedor, gerente] = await Promise.all([createUser('vendedor', { name: 'Vera Vendas' }), createUser('gerente', { name: 'Gil Gerente' })])
    const { data: s } = await service().from('settings').select('max_discount_percent').eq('id', 1).single()
    originalMax = s!.max_discount_percent
    await service().from('settings').update({ max_discount_percent: 10 }).eq('id', 1)
    const { data } = await vendedor.client.from('customers').insert({ name: `Cliente Orçamento ${uid()}` }).select().single()
    customerId = data!.id
  })

  afterAll(async () => {
    await service().from('settings').update({ max_discount_percent: originalMax }).eq('id', 1)
  })

  it('calcula os totais no servidor', async () => {
    const { data: id, error } = await vendedor.client.rpc('save_quote', {
      p_quote: { customer_id: customerId, discount_type: 'valor', discount_value: 10, items: [item(450), item(80.5, 2, 1)], total: 1 },
    })
    expect(error).toBeNull()
    const { data: q } = await vendedor.client.from('quotes').select('*, quote_items(*), quote_events(*)').eq('id', id).single()
    expect(q.subtotal).toBe(611)
    expect(q.discount_total).toBe(11)
    expect(q.total).toBe(600)
    expect(q.status).toBe('rascunho')
    expect(q.quote_items).toHaveLength(2)
    expect(q.quote_events.map((e: { event: string }) => e.event)).toEqual(['criado'])
    expect(q.valid_until).toBeTruthy()
  })

  it('rejeita itens inválidos', async () => {
    const empty = await vendedor.client.rpc('save_quote', { p_quote: { customer_id: customerId, items: [] } })
    expect(empty.error?.message).toContain('pelo menos um item')
    const neg = await vendedor.client.rpc('save_quote', { p_quote: { customer_id: customerId, items: [item(-5)] } })
    expect(neg.error?.message).toContain('não pode ser negativo')
    const big = await vendedor.client.rpc('save_quote', { p_quote: { customer_id: customerId, items: [item(100, 1, 150)] } })
    expect(big.error?.message).toContain('desconto de um item')
  })

  it('exige autorização para descontos acima do limite', async () => {
    const payload = { customer_id: customerId, discount_type: 'percentual', discount_value: 15, items: [item(1000)] }
    const denied = await vendedor.client.rpc('save_quote', { p_quote: payload })
    expect(denied.error?.message).toMatch(/Desconto de 15,00% acima do limite autorizado de 10,00%/)

    const { data: id, error } = await gerente.client.rpc('save_quote', { p_quote: payload })
    expect(error).toBeNull()
    const { data: q } = await gerente.client.from('quotes').select('discount_authorized_by, total').eq('id', id).single()
    expect(q!.discount_authorized_by).toBe(gerente.id)
    expect(q!.total).toBe(850)

    // O vendedor pode editar mantendo o desconto já autorizado, mas não aumentá-lo.
    const keep = await vendedor.client.rpc('save_quote', { p_quote: { ...payload, id, notes: 'Ajuste de observação' } })
    expect(keep.error).toBeNull()
    const more = await vendedor.client.rpc('save_quote', { p_quote: { ...payload, id, discount_value: 20 } })
    expect(more.error?.code).toBe('P0001')
  })

  it('segue o fluxo de status e bloqueia edição após aprovação', async () => {
    const { data: id } = await vendedor.client.rpc('save_quote', { p_quote: { customer_id: customerId, items: [item(300)] } })
    const invalid = await vendedor.client.rpc('set_quote_status', { p_id: id, p_status: 'concluido' })
    expect(invalid.error?.message).toContain('Não é possível alterar o status')

    for (const status of ['enviado', 'aprovado']) {
      const { error } = await vendedor.client.rpc('set_quote_status', { p_id: id, p_status: status, p_note: `para ${status}` })
      expect(error).toBeNull()
    }
    const edit = await vendedor.client.rpc('save_quote', { p_quote: { id, customer_id: customerId, items: [item(1)] } })
    expect(edit.error?.message).toContain('não podem ser editados')

    const done = await vendedor.client.rpc('set_quote_status', { p_id: id, p_status: 'concluido' })
    expect(done.error).toBeNull()
    const { data: q } = await vendedor.client.from('quotes').select('status, sent_at, decided_at, completed_at, quote_events(status, note, created_by)').eq('id', id).single()
    expect(q!.status).toBe('concluido')
    expect(q!.sent_at && q!.decided_at && q!.completed_at).toBeTruthy()
    const statuses = q!.quote_events.map((e: { status: string }) => e.status)
    expect(statuses).toEqual(expect.arrayContaining(['enviado', 'aprovado', 'concluido']))
    expect(q!.quote_events.every((e: { created_by: string }) => e.created_by === vendedor.id)).toBe(true)
  })

  it('somente quem tem permissão exclui orçamentos', async () => {
    const { data: id } = await vendedor.client.rpc('save_quote', { p_quote: { customer_id: customerId, items: [item(10)] } })
    const v = await vendedor.client.from('quotes').delete().eq('id', id).select('id')
    expect(v.data).toEqual([])
    const g = await gerente.client.from('quotes').delete().eq('id', id).select('id')
    expect(g.data).toHaveLength(1)
  })

  it('cliente com orçamento não pode ser excluído', async () => {
    const { error } = await gerente.client.from('customers').delete().eq('id', customerId)
    expect(error?.code).toBe('23503')
  })
})

describe.skipIf(!enabled)('regras de negócio: histórico, serviços, simulações e painel', () => {
  let vendedor: TestUser
  let gerente: TestUser

  beforeAll(async () => {
    ;[vendedor, gerente] = await Promise.all([createUser('vendedor'), createUser('gerente')])
  })

  it('registra no histórico quem alterou e somente os campos alterados', async () => {
    const { data: c } = await vendedor.client.from('customers').insert({ name: `Histórico ${uid()}`, city: 'Campinas' }).select().single()
    await vendedor.client.from('customers').update({ city: 'Santos' }).eq('id', c!.id)
    const { data: log } = await gerente.client.from('audit_log').select('*').eq('table_name', 'customers').eq('record_id', c!.id).order('id')
    expect(log!.map((l) => l.action)).toEqual(['INSERT', 'UPDATE'])
    const upd = log![1]
    expect(upd.changed_by).toBe(vendedor.id)
    expect(upd.old_data).toEqual({ city: 'Campinas' })
    expect(upd.new_data).toEqual({ city: 'Santos' })
    expect(upd.record_label).toBe(c!.name)
    // Ninguém consegue apagar ou forjar registros do histórico.
    const del = await gerente.client.from('audit_log').delete().eq('id', upd.id)
    expect(del.error?.code).toBe('42501')
  })

  it('ordens de serviço registram início e conclusão', async () => {
    const { data: c } = await vendedor.client.from('customers').insert({ name: `OS ${uid()}` }).select().single()
    const { data: o, error } = await vendedor.client
      .from('service_orders')
      .insert({ customer_id: c!.id, description: 'Instalação de película', vehicle_plate: 'abc-1d23' })
      .select()
      .single()
    expect(error).toBeNull()
    expect(o!.vehicle_plate).toBe('ABC1D23')
    expect(o!.created_by).toBe(vendedor.id)
    const { data: done } = await vendedor.client.from('service_orders').update({ status: 'concluido' }).eq('id', o!.id).select().single()
    expect(done!.completed_at).toBeTruthy()
    expect(done!.started_at).toBeTruthy()
  })

  it('valida a configuração das simulações', async () => {
    const { data: v } = await vendedor.client.from('vehicles').select('id').limit(1).single()
    const ok = await vendedor.client.from('simulations').insert({ vehicle_id: v!.id, mode: 'referencia', config: { dianteiros: { vlt: 35, film_id: null } } }).select().single()
    expect(ok.error).toBeNull()
    expect(ok.data!.created_by).toBe(vendedor.id)
    const bad = await vendedor.client.from('simulations').insert({ vehicle_id: v!.id, mode: 'referencia', config: { teto_solar: { vlt: 20 } } })
    expect(bad.error?.code).toBe('23514')
  })

  it('o painel usa dados reais do banco', async () => {
    const before = (await gerente.client.rpc('dashboard_stats')).data as Record<string, number>
    await vendedor.client.from('customers').insert({ name: `Painel ${uid()}` })
    const after = (await gerente.client.rpc('dashboard_stats')).data as Record<string, number>
    expect(after.customers_total).toBe(before.customers_total + 1)
    expect(after.vehicles_total).toBeGreaterThan(0)
  })
})
