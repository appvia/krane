/// <reference types="vitest/config" />
import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import sirv from 'sirv'
import { defineConfig, type PluginOption } from 'vite'

// Serves report data out of the directory the Ruby side writes it to, so
// `npm run dev` works against a locally generated report with HMR on top.
function reportData(): PluginOption {
  return {
    name: 'krane-report-data',
    configureServer(server) {
      const dataDir = fileURLToPath(new URL('./compiled/data', import.meta.url))
      server.middlewares.use('/data', sirv(dataDir, { dev: true, etag: true }))
    },
  }
}

export default defineConfig({
  plugins: [vue(), tailwindcss(), reportData()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  build: {
    outDir: 'compiled',
    // compiled/data is written by `krane report`, not by the build. `npm run
    // clean` empties everything else.
    emptyOutDir: false,
    assetsDir: 'assets',
    sourcemap: false,
    // vis-network is ~530 kB on its own and cannot be split usefully. The graph
    // is a lazily routed view, so it only costs the people who open it.
    chunkSizeWarningLimit: 600,
  },
  test: {
    environment: 'happy-dom',
    include: ['src/**/*.spec.ts'],
    setupFiles: ['./vitest.setup.ts'],
  },
})
