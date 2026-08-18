// Empties the build output without touching compiled/data: the Ruby side writes
// report data into the same tree, and a report is expensive to regenerate.
import { readdir, rm } from 'node:fs/promises'
import { fileURLToPath, URL } from 'node:url'

const outDir = fileURLToPath(new URL('../compiled', import.meta.url))
const keep = new Set(['data'])

let entries
try {
  entries = await readdir(outDir)
} catch (error) {
  if (error.code === 'ENOENT') process.exit(0)
  throw error
}

await Promise.all(
  entries
    .filter((entry) => !keep.has(entry))
    .map((entry) => rm(new URL(`../compiled/${entry}`, import.meta.url), { recursive: true, force: true })),
)
