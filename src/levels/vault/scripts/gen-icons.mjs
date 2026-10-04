// Renders public/icon.svg to PNG icons using the preinstalled Chromium.
// Usage: NODE_PATH=$(npm root -g) node src/levels/vault/scripts/gen-icons.mjs
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const { chromium } = require('playwright')
const root = resolve(import.meta.dirname, '../../../..')
const svg = readFileSync(resolve(root, 'public/icon.svg'), 'utf8')

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' }).catch(() => chromium.launch())
const page = await browser.newPage()
const targets = [
  ['icon-192.png', 192, 1],
  ['icon-512.png', 512, 1],
  ['icon-maskable-512.png', 512, 0.8], // safe zone padding for maskable
  ['apple-touch-icon.png', 180, 1],
]
for (const [name, size, scale] of targets) {
  await page.setViewportSize({ width: size, height: size })
  const inner = Math.round(size * scale)
  await page.setContent(
    `<html><body style="margin:0;background:#05080f;display:grid;place-items:center;width:${size}px;height:${size}px">` +
      svg.replace('<svg ', `<svg width="${inner}" height="${inner}" `) +
      `</body></html>`,
  )
  await page.screenshot({ path: resolve(root, 'public', name), omitBackground: false })
  console.log('wrote', name)
}
await browser.close()
