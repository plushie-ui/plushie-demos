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

const app = (await import("../src/collab.tsx")).default
const session = await createSession(app, { mode: "headless" })
await session.start()
await new Promise((r) => setTimeout(r, 300))

// Type a name
await session.typeText("name", "Alice")
await new Promise((r) => setTimeout(r, 200))

// Click increment a few times
await session.click("inc")
await session.click("inc")
await session.click("inc")
await new Promise((r) => setTimeout(r, 200))

savePng("collab-filled", await session.screenshot("filled"))

// Toggle dark mode
await session.toggle("theme")
await new Promise((r) => setTimeout(r, 200))

savePng("collab-dark", await session.screenshot("dark"))

session.stop()
stopPool()
process.exit(0)
