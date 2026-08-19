// Highlighting is done by splitting the text into parts and letting the template
// render them, rather than by building markup: node text is cluster RBAC and
// must never be interpreted as HTML.

export type TextPart = {
  text: string
  hit: boolean
}

export function highlight(text: string, query: string): TextPart[] {
  const needle = query.trim().toLowerCase()
  if (needle === '' || text === '') return [{ text, hit: false }]

  const haystack = text.toLowerCase()
  const parts: TextPart[] = []
  let cursor = 0

  for (let found = haystack.indexOf(needle); found !== -1; found = haystack.indexOf(needle, cursor)) {
    if (found > cursor) parts.push({ text: text.slice(cursor, found), hit: false })
    parts.push({ text: text.slice(found, found + needle.length), hit: true })
    cursor = found + needle.length
  }

  if (parts.length === 0) return [{ text, hit: false }]
  if (cursor < text.length) parts.push({ text: text.slice(cursor), hit: false })

  return parts
}
