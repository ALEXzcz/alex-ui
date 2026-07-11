import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: '/alex/',
  server: {
    port: 10086,
    host: true,
    open: true,
    proxy: {
      '/api': {
        target: 'http://192.168.156.158:8888',
        changeOrigin: true,
        secure: false,
        ws: true,
      }
    }
  },
  build: {
    outDir: 'dist'
  }
})