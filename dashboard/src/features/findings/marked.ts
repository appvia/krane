// Findings arrive as one sentence per item, with the objects they are about
// wrapped in backticks by the Ruby writers. Splitting on those is how the name
// gets picked out of the prose without the frontend guessing at the shape of a
// sentence it did not write.

export type ItemPart = {
  text: string
  /** An object's name, rather than the words around it. */
  name: boolean
}

const MARKED = /`([^`]*)`/g

export function marked(item: string): ItemPart[] {
  const parts: ItemPart[] = []
  let cursor = 0

  for (const match of item.matchAll(MARKED)) {
    const at = match.index
    if (at > cursor) parts.push({ text: item.slice(cursor, at), name: false })
    parts.push({ text: match[1] ?? '', name: true })
    cursor = at + match[0].length
  }

  if (cursor < item.length) parts.push({ text: item.slice(cursor), name: false })

  // An item from a rule that marks nothing is all prose, and reads as before.
  return parts.length > 0 ? parts : [{ text: item, name: false }]
}
