import { fileURLToPath } from 'node:url'
import { createClient } from '@supabase/supabase-js'
import { expect, test, type Page } from '@playwright/test'
import { e2eUser, login } from './support'

/** Luminância média do canvas 3D (preserveDrawingBuffer habilitado no Stage). */
async function canvasLuma(page: Page) {
  return page.locator('canvas').first().evaluate((canvas: HTMLCanvasElement) => {
    const c = document.createElement('canvas')
    c.width = 160
    c.height = 100
    const ctx = c.getContext('2d')!
    ctx.drawImage(canvas, 0, 0, c.width, c.height)
    const { data } = ctx.getImageData(0, 0, c.width, c.height)
    let sum = 0
    for (let i = 0; i < data.length; i += 4) sum += 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]
    return sum / (data.length / 4)
  })
}

test('modelo 3D: envio com licença, mapeamento dos vidros e simulação em tempo real', async ({ page }) => {
  const { suffix } = e2eUser()
  const admin = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, { auth: { persistSession: false } })
  const { data: vehicle, error } = await admin
    .from('vehicles')
    .insert({ brand: 'Teste E2E', model: `3D ${suffix}`, generation: 'Sintético', category: 'sedan' })
    .select()
    .single()
  expect(error).toBeNull()

  await login(page)
  await page.goto(`/app/garagem/${vehicle!.id}`)
  await page.getByLabel('Arquivo do modelo (.glb)').setInputFiles(fileURLToPath(new URL('./fixtures/modelo-sintetico.glb', import.meta.url)))
  await page.getByRole('button', { name: 'Enviar modelo' }).click()
  await expect(page.getByText('Informe a origem e a licença/autorização de uso do modelo.')).toBeVisible()
  await page.getByLabel('Origem e licença').fill('Modelo sintético gerado para teste automatizado')
  await page.getByRole('button', { name: 'Enviar modelo' }).click()
  await expect(page.getByText('Modelo 3D enviado. Agora associe as malhas de vidro às zonas.')).toBeVisible()

  await expect(page.getByText('Windshield', { exact: true })).toBeVisible({ timeout: 20_000 })
  await page.getByRole('button', { name: 'Sugerir pelo nome' }).click()
  await expect(page.getByText('6 malha(s) associadas pelo nome. Revise antes de salvar.')).toBeVisible()
  await expect(page.getByLabel('Zona da malha Windshield')).toHaveValue('para_brisa')
  await expect(page.getByLabel('Zona da malha Rear_Window')).toHaveValue('vidro_traseiro')
  await expect(page.getByLabel('Zona da malha Window_Front_R')).toHaveValue('dianteiros')
  await expect(page.getByLabel('Zona da malha Window_Rear_L')).toHaveValue('traseiros')
  await page.getByRole('button', { name: 'Salvar mapeamento' }).click()
  await expect(page.getByText('Mapeamento dos vidros salvo.')).toBeVisible()
  await expect(page.getByText('6 malha(s) de vidro mapeadas')).toBeVisible()

  await page.getByRole('button', { name: 'Simular películas' }).click()
  await expect(page.getByRole('radio', { name: 'Modelo 3D' })).toHaveAttribute('aria-checked', 'true')
  await page.waitForTimeout(2500)
  const before = await canvasLuma(page)
  await page.locator('select').first().selectOption('custom')
  for (const zone of ['para_brisa', 'dianteiros', 'traseiros', 'vidro_traseiro']) {
    await page.locator(`[data-zone="${zone}"]`).getByRole('button', { name: '5%', exact: true }).click()
  }
  await page.waitForTimeout(800)
  const after = await canvasLuma(page)
  expect(after).toBeLessThan(before - 0.5)

  await page.getByRole('button', { name: 'Comparar' }).click()
  await expect(page.getByRole('slider', { name: 'Divisão entre original e simulação' })).toBeVisible()
  await page.waitForTimeout(600)
  const split = await canvasLuma(page)
  expect(split).toBeGreaterThan(after)
})
