import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  server: { port: 5173, host: true },
  preview: { port: 4173, host: true },
  build: {
    chunkSizeWarningLimit: 1200,
    rollupOptions: {
      output: {
        // Somente bibliotecas usadas na carga inicial; o 3D fica em chunks carregados sob demanda.
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom', '@tanstack/react-query'],
          supabase: ['@supabase/supabase-js'],
        },
      },
    },
  },
})
