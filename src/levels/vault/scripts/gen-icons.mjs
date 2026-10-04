// Renders public/icon.svg to PNG icons using the preinstalled Chromium.
// Usage: NODE_PATH=$(npm root -g) node src/levels/vault/scripts/gen-icons.mjs
//
// - icon-192 / icon-512 ("any"): rounded app-icon shape on a transparent background.
// - icon-maskable-512: full-bleed square, artwork scaled into the 80% safe zone.
// - apple-touch-icon: full-bleed square (iOS applies its own rounded mask).
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const { chromium } = require('playwright')
const root = resolve(import.meta.dirname, '../../../..')
const svg = readFileSync(resolve(root, 'public/icon.svg'), 'utf8')
const BG = '#ffffff'

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' }).catch(() => chromium.launch())
const page = await browser.newPage()
const targets = [
  // name, size, artwork scale, rounded?
  ['icon-192.png', 192, 1, true],
  ['icon-512.png', 512, 1, true],
  ['icon-maskable-512.png', 512, 0.8, false],
  ['apple-touch-icon.png', 180, 1, false],
]
for (const [name, size, scale, rounded] of targets) {
  await page.setViewportSize({ width: size, height: size })
  const inner = Math.round(size * scale)
  const radius = rounded ? Math.round(size * 0.225) : 0
  const tile = rounded ? `border-radius:${radius}px;overflow:hidden;` : ''
  await page.setContent(
    `<html><body style="margin:0;background:transparent">` +
      `<div style="width:${size}px;height:${size}px;background:${BG};display:grid;place-items:center;position:relative;${tile}">` +
      svg.replace('<svg ', `<svg width="${inner}" height="${inner}" style="display:block" `) +
      // hairline edge so the white tile still reads on white backgrounds
      (rounded ? `<div style="position:absolute;inset:0;border-radius:${radius}px;box-shadow:inset 0 0 0 ${Math.max(1, size / 256)}px rgba(0,0,0,.06)"></div>` : '') +
      `</div></body></html>`,
  )
  await page.screenshot({ path: resolve(root, 'public', name), omitBackground: rounded })
  console.log('wrote', name)
}
await browser.close()
