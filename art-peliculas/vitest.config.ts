import { defineConfig } from 'vitest/config'
import { fileURLToPath, URL } from 'node:url'

const alias = { '@': fileURLToPath(new URL('./src', import.meta.url)) }

export default defineConfig({
  test: {
    fileParallelism: false,
    projects: [
      {
        resolve: { alias },
        test: { name: 'unit', include: ['src/**/*.test.{ts,tsx}'], environment: 'jsdom', setupFiles: ['./src/test/setup.ts'] },
      },
      {
        resolve: { alias },
        test: {
          name: 'integration',
          include: ['tests/integration/**/*.test.ts'],
          environment: 'node',
          testTimeout: 30000,
          hookTimeout: 60000,
        },
      },
    ],
  },
})
