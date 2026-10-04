import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// Relative base so the build works at any path (e.g. GitHub Pages at /Friday/).
export default defineConfig({
  base: './',
  plugins: [react()],
})
