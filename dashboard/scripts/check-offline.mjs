// Fails if the build references anything it would have to fetch from the
// internet. Krane runs in air gapped clusters, and the old dashboard silently
// depended on Google Fonts and cdnjs — which meant no fonts and no icons there.
//
// Report data is skipped: it is generated from cluster RBAC and from the user's
// own rules.yaml, both of which may legitimately mention a URL.
import { readdir, readFile } from 'node:fs/promises'
import { join, relative } from 'node:path'
import { fileURLToPath, URL } from 'node:url'

const root = fileURLToPath(new URL('../compiled', import.meta.url))
const skip = new Set(['data'])

// URLs that appear as text and are never fetched. Prefixes rather than whole
// hosts: waving through a host is more than this needs.
const allowed = [
  'http://www.w3.org/', // SVG, MathML and XLink namespace identifiers
  'https://www.w3.org/',
  'https://vuejs.org/error-reference/', // the runtime's "this error explained" link
  'https://tailwindcss.com', // a comment in the generated CSS
  'https://rolldown.rs/reference/', // a comment in the generated JS
  'https://github.com/zloirock/core-js', // core-js's licence banner, via vis-network
]

const URLS = /https?:\/\/[^\s"'`)\\]+/g

async function* files(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!skip.has(entry.name)) yield* files(join(directory, entry.name))
    } else if (/\.(js|mjs|css|html|json|svg)$/.test(entry.name)) {
      yield join(directory, entry.name)
    }
  }
}

const offenders = []

for await (const file of files(root)) {
  const contents = await readFile(file, 'utf8')
  for (const match of contents.match(URLS) ?? []) {
    if (!allowed.some((prefix) => match.startsWith(prefix))) {
      offenders.push(`${relative(root, file)}: ${match}`)
    }
  }
}

if (offenders.length > 0) {
  console.error('The build references remote resources, which will not load in an air gapped cluster:')
  for (const offender of [...new Set(offenders)]) console.error(`  ${offender}`)
  process.exit(1)
}

console.log('No remote references in the build.')
