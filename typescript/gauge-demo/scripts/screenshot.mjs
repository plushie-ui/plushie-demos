import { createSession, stopPool } from "plushie/testing"
import { mkdirSync, writeFileSync } from "node:fs"
import { execSync } from "node:child_process"

const dir = "/tmp/plushie_screenshots"
mkdirSync(dir, { recursive: true })

const app = (await import("../src/app.tsx")).default
const session = await createSession(app, { mode: "headless" })
await session.start()
await new Promise((r) => setTimeout(r, 500))

const result = await session.screenshot("verify")
console.log(`Screenshot: ${result.width}x${result.height}`)

if (result.rgba && (result.rgba instanceof Uint8Array || Buffer.isBuffer(result.rgba))) {
  const rgbaPath = `${dir}/gauge-demo.rgba`
  writeFileSync(rgbaPath, result.rgba)
  execSync(`convert -size ${result.width}x${result.height} -depth 8 rgba:${rgbaPath} ${dir}/gauge-demo.png`)
  console.log(`Saved: ${dir}/gauge-demo.png`)
}

session.stop()
stopPool()
process.exit(0)
