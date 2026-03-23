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

// Increment counter then throw handler
await session.click("inc")
await session.click("inc")
await session.click("throw_handler")
await session.click("inc") // should still work
await new Promise((r) => setTimeout(r, 200))

savePng("crash-after-throw", await session.screenshot("after-throw"))

// Trigger view throw
await session.click("throw_view")
await session.click("inc") // handler runs but view frozen
await new Promise((r) => setTimeout(r, 200))

savePng("crash-view-frozen", await session.screenshot("view-frozen"))

// Reset
await session.click("reset")
await new Promise((r) => setTimeout(r, 200))

savePng("crash-recovered", await session.screenshot("recovered"))

session.stop()
stopPool()
process.exit(0)
