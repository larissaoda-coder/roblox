import { fileURLToPath } from 'node:url'
import { expect, test, type Page } from '@playwright/test'
import { e2eUser, login } from './support'

function randomCpf() {
  const n = Array.from({ length: 9 }, () => Math.floor(Math.random() * 10))
  const dv = (d: number[]) => {
    const r = (d.reduce((a, x, i) => a + x * (d.length + 1 - i), 0) * 10) % 11
    return r === 10 ? 0 : r
  }
  const d1 = dv(n)
  return [...n, d1, dv([...n, d1])].join('')
}

/** Clica em pontos (coordenadas normalizadas) sobre a área de desenho das máscaras. */
async function drawPolygon(page: Page, points: Array<[number, number]>) {
  const svg = page.getByRole('application', { name: 'Área de desenho das máscaras dos vidros' })
  const box = (await svg.boundingBox())!
  for (const [x, y] of points) await page.mouse.click(box.x + x * box.width, box.y + y * box.height)
  await page.getByRole('button', { name: 'Fechar polígono' }).click()
}

test('fluxo completo: catálogo, cliente, garagem, simulação, orçamento, serviço e impressão', async ({ page }) => {
  const { suffix } = e2eUser()
  const filmName = `G20 ${suffix}`
  const customerName = `Cliente E2E ${suffix}`
  let quoteUrl = ''

  await login(page)

  await test.step('cadastra uma película no catálogo', async () => {
    await page.getByRole('link', { name: 'Catálogo de películas' }).click()
    await page.getByRole('button', { name: 'Nova película' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByRole('button', { name: 'Cadastrar película' }).click()
    await expect(dialog.getByText('Informe o nome.')).toBeVisible()
    await dialog.getByLabel('Nome do produto').fill(filmName)
    await dialog.getByLabel('Linha').fill('Nano cerâmica')
    await dialog.getByLabel('Fabricante').fill('Fabricante Teste')
    await dialog.getByLabel('Fabricante').press('Escape')
    await dialog.getByLabel('Transmissão luminosa (VLT %)').fill('20')
    await dialog.getByLabel('Preço (R$)').fill('350')
    await dialog.getByLabel('Rejeição UV (%)').fill('99')
    await dialog.getByRole('button', { name: 'Adicionar característica' }).click()
    await dialog.getByLabel('Nome da característica').fill('Espessura')
    await dialog.getByLabel('Valor da característica').fill('1,5 mil')
    await dialog.getByRole('button', { name: 'Cadastrar película' }).click()
    await expect(page.getByText('Película cadastrada no catálogo.')).toBeVisible()
    await expect(page.getByRole('cell', { name: new RegExp(filmName) }).first()).toBeVisible()
  })

  await test.step('cadastra um cliente com validação de CPF', async () => {
    await page.getByRole('link', { name: 'Clientes' }).click()
    await page.getByRole('button', { name: 'Novo cliente' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('Nome completo ou razão social').fill(customerName)
    await dialog.getByLabel('CPF ou CNPJ').fill('111.111.111-11')
    await dialog.getByLabel('Telefone / WhatsApp').fill('11987654321')
    await dialog.getByRole('button', { name: 'Cadastrar cliente' }).click()
    await expect(dialog.getByText('CPF ou CNPJ inválido.')).toBeVisible()
    await dialog.getByLabel('CPF ou CNPJ').fill(randomCpf())
    await dialog.getByRole('button', { name: 'Cadastrar cliente' }).click()
    await expect(page.getByRole('heading', { level: 1, name: customerName })).toBeVisible()
    await expect(page.getByText('(11) 98765-4321')).toBeVisible()
  })

  await test.step('cadastra um veículo na garagem', async () => {
    await page.getByRole('link', { name: 'Garagem de veículos' }).click()
    await page.getByLabel('Buscar veículos').fill('Corolla')
    await expect(page.getByText(/de 5\d veículos|de \d+ veículos/)).toBeVisible()
    await page.getByRole('button', { name: 'Novo veículo' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('Modelo').fill(`Modelo ${suffix}`)
    await dialog.getByLabel('Geração / versão').fill('1ª geração')
    // O campo de marca tem sugestões nativas (datalist); é preenchido por último e o popup é fechado.
    await dialog.getByLabel('Marca').fill('Teste E2E')
    await dialog.getByLabel('Marca').press('Escape')
    await dialog.getByLabel('Categoria').selectOption('sedan')
    await dialog.getByLabel('Ano inicial').fill('2022')
    await dialog.getByLabel('Ano final').fill('2019')
    await dialog.getByRole('button', { name: 'Cadastrar veículo' }).click()
    await expect(dialog.getByText('O ano final deve ser igual ou posterior ao inicial.')).toBeVisible()
    await dialog.getByLabel('Ano final').fill('')
    await dialog.getByRole('button', { name: 'Cadastrar veículo' }).click()
    await expect(page.getByRole('heading', { level: 1 })).toContainText(`Modelo ${suffix}`)
    await expect(page.getByText('2022–atual')).toBeVisible()
  })

  await test.step('envia imagem autorizada e desenha as máscaras dos vidros', async () => {
    await page.getByRole('button', { name: 'Adicionar imagem' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('Arquivo de imagem').setInputFiles(fileURLToPath(new URL('./fixtures/veiculo-sintetico.png', import.meta.url)))
    await dialog.getByLabel('Origem e autorização de uso').fill('Imagem sintética gerada para teste automatizado')
    await dialog.getByRole('button', { name: 'Enviar imagem' }).click()

    await expect(page.getByRole('heading', { name: 'Máscaras dos vidros' })).toBeVisible({ timeout: 20_000 })
    await drawPolygon(page, [
      [0.665, 0.345],
      [0.775, 0.345],
      [0.78, 0.5],
      [0.7, 0.5],
    ])
    await page.getByRole('radio', { name: /^Dianteiros/ }).click()
    await drawPolygon(page, [
      [0.51, 0.36],
      [0.64, 0.36],
      [0.74, 0.51],
      [0.51, 0.51],
    ])
    await page.getByRole('radio', { name: /^Traseiros/ }).click()
    await drawPolygon(page, [
      [0.3, 0.51],
      [0.37, 0.36],
      [0.485, 0.36],
      [0.485, 0.51],
    ])
    await page.getByRole('button', { name: 'Pré-visualizar' }).click()
    await page.getByRole('button', { name: 'Salvar máscaras' }).click()
    await expect(page.getByText('Máscaras salvas.')).toBeVisible()
    await expect(page.getByText('3 zona(s) com máscara')).toBeVisible()
  })

  await test.step('associa a película ao veículo com preço específico', async () => {
    await page.getByRole('button', { name: 'Associar película' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByRole('combobox').fill(suffix)
    await dialog.getByRole('option', { name: new RegExp(filmName) }).click()
    await dialog.getByLabel('Preço para este veículo (opcional)').fill('300')
    await dialog.getByRole('button', { name: 'Associar' }).click()
    await expect(page.getByText('Preço para este veículo: R$ 300,00')).toBeVisible()
  })

  await test.step('simula as películas sobre a imagem e salva a simulação', async () => {
    await page.getByRole('button', { name: 'Simular películas' }).click()
    await expect(page).toHaveURL(/\/app\/simulador\?veiculo=/)
    await expect(page.getByRole('radio', { name: 'Foto · Frente 3/4' })).toHaveAttribute('aria-checked', 'true')

    const filmValue = await page.locator('#zone-dianteiros option', { hasText: filmName }).first().getAttribute('value')
    await page.locator('#zone-dianteiros').selectOption(filmValue!)
    await page.locator('#zone-traseiros').selectOption('custom')
    await expect(page.locator('[data-zone="dianteiros"]').getByText('Abaixo da referência legal')).toBeVisible()
    await expect(page.locator('[data-zone="vidro_traseiro"]').getByText('Não aparece nesta vista')).toBeVisible()

    // Somente as áreas envidraçadas recebem a camada escura.
    // (aguarda a transição suave de opacidade)
    await expect
      .poll(() =>
        page
          .locator('svg[role="img"] polygon')
          .evaluateAll((els) => els.map((e) => Number(getComputedStyle(e).fillOpacity)).filter((v) => v > 0.3).length),
      )
      .toBe(2)

    await page.getByRole('button', { name: 'Comparar' }).click()
    await expect(page.getByRole('slider', { name: 'Divisão entre original e simulação' })).toBeVisible()

    await page.getByRole('button', { name: 'Salvar simulação' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByRole('combobox').fill(suffix)
    await dialog.getByRole('option', { name: customerName }).click()
    await dialog.getByLabel('Observações (opcional)').fill('Cliente preferiu 20% nas dianteiras.')
    await dialog.getByRole('button', { name: 'Salvar simulação' }).click()
    await expect(page.getByText('Simulação salva com sucesso.')).toBeVisible()
  })

  await test.step('gera o orçamento a partir da simulação', async () => {
    await page.getByRole('button', { name: 'Gerar orçamento' }).click()
    await expect(page).toHaveURL(/\/app\/orcamentos\/novo\?simulacao=/)
    await expect(page.getByTestId('quote-item')).toHaveCount(2)
    await expect(page.getByLabel('Descrição do item').first()).toHaveValue(new RegExp(filmName))
    await expect(page.getByRole('combobox').first()).toHaveAttribute('placeholder', customerName)

    await page.getByRole('button', { name: 'Criar orçamento' }).click()
    await expect(page.getByText('Informe o valor unitário.')).toBeVisible()
    await page.getByLabel('Valor unit. (R$)').nth(1).fill('150')
    await page.getByLabel('Placa').fill('abc1d23')
    await page.getByRole('radio', { name: '%' }).click()
    await page.getByLabel('Valor do desconto').fill('5')
    await expect(page.locator('aside').getByText('R$ 427,50')).toBeVisible()
    await page.getByRole('button', { name: 'Criar orçamento' }).click()
    await expect(page).toHaveURL(/\/app\/orcamentos\/[0-9a-f-]{36}$/)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('ORC-')
    await expect(page.getByText('R$ 427,50').first()).toBeVisible()
    quoteUrl = page.url()
  })

  await test.step('acompanha o status e gera a ordem de serviço', async () => {
    await page.getByRole('button', { name: 'Marcar como enviado' }).click()
    await page.getByRole('dialog').getByRole('button', { name: 'Confirmar' }).click()
    await expect(page.getByText('Status alterado para enviado.')).toBeVisible()
    await page.getByRole('button', { name: 'Aprovar' }).click()
    await page.getByRole('dialog').getByLabel('Observação (opcional)').fill('Aprovado por telefone')
    await page.getByRole('dialog').getByRole('button', { name: 'Confirmar' }).click()
    await expect(page.getByText('Status alterado para aprovado.')).toBeVisible()
    await expect(page.getByText('“Aprovado por telefone”')).toBeVisible()
    await expect(page.getByRole('button', { name: 'Editar' })).toHaveCount(0)

    await page.getByRole('button', { name: 'Gerar ordem de serviço' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('Data e hora').fill('2030-05-20T09:30')
    await dialog.getByRole('button', { name: 'Registrar serviço' }).click()
    await expect(page.getByText('Ordem de serviço registrada.')).toBeVisible()
    await expect(page.getByText(/OS-\d{5}/).first()).toBeVisible()
  })

  await test.step('imprime o orçamento', async () => {
    await page.goto(`${quoteUrl}/imprimir`)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('ORC-')
    await expect(page.getByText(customerName).first()).toBeVisible()
    await expect(page.getByText('Placa ABC1D23')).toBeVisible()
    await expect(page.getByText('R$ 427,50').first()).toBeVisible()
    await expect(page.getByRole('button', { name: 'Imprimir / salvar PDF' })).toBeVisible()
  })

  await test.step('painel e histórico refletem os dados', async () => {
    await page.goto('/app')
    await expect(page.getByText(customerName).first()).toBeVisible()
    await expect(page.getByText(`Teste E2E Modelo ${suffix} 1ª geração`).first()).toBeVisible()
    await expect(page.getByText(/Dianteiros 20% · Traseiros 35%/).first()).toBeVisible()
    await page.goto('/app/historico')
    await expect(page.getByText(customerName).first()).toBeVisible()
    await expect(page.getByText(/ORC-\d{5}/).first()).toBeVisible()
  })
})
