// Holds the flattened tree and everything derived from it. Grows as chunks are
// grafted on, and answers "what rows are visible" in time proportional to the
// rows on screen rather than to the size of the tree.

import type { FlatNodes } from '@/features/tree/flatten'

const NONE = -1

export type TreeMatches = {
  /** Matching node ids, capped. */
  ids: number[]
  /** How many nodes matched in total, capped or not. */
  total: number
}

export class TreeStore {
  size = 0

  texts: string[] = []
  tags: string[] = []
  branches: string[] = []
  chunks: (string | null)[] = []

  parent = new Int32Array(0)
  firstChild = new Int32Array(0)
  nextSibling = new Int32Array(0)
  depth = new Uint8Array(0)
  nodeCount = new Int32Array(0)

  readonly expanded = new Set<number>()
  /** Chunk paths already grafted, so a second expand does not refetch. */
  readonly grafted = new Set<string>()

  /** Where the next graft's ids start. */
  get nextId(): number {
    return this.size
  }

  /**
   * Appends nodes whose ids already start at nextId, hanging them off `parentId`
   * (or leaving them as roots when it is -1).
   */
  graft(parentId: number, flat: FlatNodes): void {
    if (flat.count === 0) return

    const first = this.size
    this.reserve(first + flat.count)

    for (let i = 0; i < flat.count; i += 1) {
      this.texts.push(flat.texts[i] ?? '')
      this.tags.push(flat.tags[i] ?? '')
      this.branches.push(flat.branches[i] ?? '')
      this.chunks.push(flat.chunks[i] ?? null)
    }

    this.parent.set(flat.parent, first)
    this.firstChild.set(flat.firstChild, first)
    this.nextSibling.set(flat.nextSibling, first)
    this.depth.set(flat.depth, first)
    this.nodeCount.set(flat.nodeCount, first)
    this.size = first + flat.count

    if (parentId !== NONE) {
      this.firstChild[parentId] = first
      const chunk = this.chunks[parentId]
      if (chunk) this.grafted.add(chunk)
    }
  }

  roots(): number[] {
    const ids: number[] = []
    for (let id = 0; id < this.size; id += 1) {
      if (this.parent[id] === NONE) ids.push(id)
    }
    return ids
  }

  children(id: number): number[] {
    const ids: number[] = []
    for (let child = this.firstChild[id] ?? NONE; child !== NONE; child = this.nextSibling[child] ?? NONE) {
      ids.push(child)
    }
    return ids
  }

  /** A chunk reference counts as children: they are simply not here yet. */
  hasChildren(id: number): boolean {
    return this.firstChild[id] !== NONE || this.chunks[id] !== null
  }

  /** The chunk to fetch before this node can be expanded, if any. */
  pendingChunk(id: number): string | null {
    if (this.firstChild[id] !== NONE) return null
    const chunk = this.chunks[id]
    return chunk && !this.grafted.has(chunk) ? chunk : null
  }

  isExpanded(id: number): boolean {
    return this.expanded.has(id)
  }

  expand(id: number): void {
    if (this.hasChildren(id)) this.expanded.add(id)
  }

  collapse(id: number): void {
    this.expanded.delete(id)
  }

  toggle(id: number): void {
    if (this.expanded.has(id)) this.collapse(id)
    else this.expand(id)
  }

  collapseAll(): void {
    this.expanded.clear()
  }

  ancestors(id: number): number[] {
    const path: number[] = []
    for (let current = this.parent[id] ?? NONE; current !== NONE; current = this.parent[current] ?? NONE) {
      path.unshift(current)
    }
    return path
  }

  expandAncestors(ids: readonly number[]): void {
    for (const id of ids) {
      for (const ancestor of this.ancestors(id)) this.expanded.add(ancestor)
    }
  }

  /** Rows in display order: a depth first walk that skips collapsed subtrees. */
  visible(): number[] {
    const rows: number[] = []
    const stack = this.roots().reverse()

    while (stack.length > 0) {
      const id = stack.pop() as number
      rows.push(id)
      if (this.expanded.has(id)) {
        const children = this.children(id)
        for (let i = children.length - 1; i >= 0; i -= 1) stack.push(children[i] as number)
      }
    }

    return rows
  }

  /**
   * Case insensitive substring search over the loaded nodes. Lowercasing on the
   * fly rather than keeping a second copy of every string: the tree's text is
   * its bulk, and doubling it to save a few milliseconds is a bad trade.
   */
  search(query: string, limit = 500): TreeMatches {
    const needle = query.trim().toLowerCase()
    if (needle === '') return { ids: [], total: 0 }

    const ids: number[] = []
    let total = 0

    for (let id = 0; id < this.size; id += 1) {
      if ((this.texts[id] ?? '').toLowerCase().includes(needle)) {
        total += 1
        if (ids.length < limit) ids.push(id)
      }
    }

    return { ids, total }
  }

  private reserve(required: number): void {
    if (required <= this.parent.length) return

    let capacity = Math.max(this.parent.length, 1024)
    while (capacity < required) capacity *= 2

    this.parent = grow(this.parent, capacity, Int32Array)
    this.firstChild = grow(this.firstChild, capacity, Int32Array)
    this.nextSibling = grow(this.nextSibling, capacity, Int32Array)
    this.nodeCount = grow(this.nodeCount, capacity, Int32Array)
    this.depth = grow(this.depth, capacity, Uint8Array)
  }
}

function grow<T extends Int32Array | Uint8Array>(
  column: T,
  capacity: number,
  Constructor: { new (length: number): T },
): T {
  const grown = new Constructor(capacity)
  grown.set(column)
  return grown
}
