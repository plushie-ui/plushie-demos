import { createSession, stopPool } from "plushie/testing"
import { mkdirSync, writeFileSync } from "node:fs"
import { execSync } from "node:child_process"

const dir = "/tmp/plushie_screenshots"
mkdirSync(dir, { recursive: true })

function savePng(name, result) {
  if (!result.rgba || !(result.rgba instanceof Uint8Array || Buffer.isBuffer(result.rgba))) return
  const rgbaPath = `${dir}/${name}.rgba`
  writeFileSync(rgbaPath, result.rgba)
  execSync(`convert -size ${result.width}x${result.height} -depth 8 rgba:${rgbaPath} ${dir}/${name}.png`)
  console.log(`Saved: ${dir}/${name}.png`)
}

const app = (await import("../src/app.tsx")).default
const session = await createSession(app, { mode: "headless" })
await session.start()
await new Promise((r) => setTimeout(r, 300))

// Initial state
savePng("data-explorer-init", await session.screenshot("init"))

// Search for "asia"
await session.typeText("search", "asia")
await new Promise((r) => setTimeout(r, 300))
savePng("data-explorer-search", await session.screenshot("search"))

// Sort by population descending
await session.sort("data", "population", "desc")
await new Promise((r) => setTimeout(r, 300))
savePng("data-explorer-sorted", await session.screenshot("sorted"))

// Navigate to page 2
await session.click("next")
await new Promise((r) => setTimeout(r, 300))
savePng("data-explorer-page2", await session.screenshot("page2"))

session.stop()
stopPool()
process.exit(0)
