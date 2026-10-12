import { expect, test } from '@playwright/test'
import { expectNoHorizontalScroll, login } from './support'

const VIEWPORTS = [
  { name: 'celular', width: 390, height: 844 },
  { name: 'tablet', width: 820, height: 1180 },
]

const PAGES = ['/app', '/app/garagem', '/app/simulador', '/app/peliculas', '/app/clientes', '/app/orcamentos', '/app/orcamentos/novo', '/app/servicos', '/app/historico', '/app/usuarios', '/app/configuracoes']

for (const vp of VIEWPORTS) {
  test(`layout responsivo — ${vp.name}`, async ({ page }) => {
    await page.setViewportSize({ width: vp.width, height: vp.height })
    await page.goto('/')
    await expectNoHorizontalScroll(page)
    await page.screenshot({ path: `test-results/responsive/${vp.name}-inicio.png`, fullPage: true })
    await page.goto('/entrar')
    await expectNoHorizontalScroll(page)
    await login(page)

    for (const path of PAGES) {
      await page.goto(path)
      await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
      await page.waitForTimeout(400)
      await expectNoHorizontalScroll(page)
      await page.screenshot({ path: `test-results/responsive/${vp.name}${path.replace(/\//g, '-')}.png`, fullPage: true })
    }

    // Menu lateral vira gaveta em telas menores.
    await page.goto('/app')
    await expect(page.getByRole('navigation', { name: 'Menu principal' })).toBeHidden()
    await page.getByRole('button', { name: 'Abrir menu' }).click()
    const drawer = page.getByRole('dialog', { name: 'Menu' })
    await expect(drawer.getByRole('link', { name: 'Orçamentos' })).toBeVisible()
    await drawer.getByRole('link', { name: 'Orçamentos' }).click()
    await expect(page).toHaveURL(/\/app\/orcamentos$/)
    await expect(drawer).toBeHidden()
  })
}
