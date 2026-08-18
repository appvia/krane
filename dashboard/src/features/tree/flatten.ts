// The tree arrives as nested objects and can be tens of megabytes. Rendering it
// needs a flat, indexable shape, so it is turned into columnar arrays once: one
// entry per node, children reached through firstChild/nextSibling links rather
// than through arrays of objects.

import type { RbacTreeNode } from '@/lib/types'

export type FlatNodes = {
  count: number
  /** Display text, as published. */
  texts: string[]
  /**
   * Tags joined for display. The same handful of tag strings repeat across the
   * whole tree, so one interned string per node costs far less than an array.
   */
  tags: string[]
  branches: string[]
  /** Where a node's children live, when they were not inlined. */
  chunks: (string | null)[]
  parent: Int32Array
  firstChild: Int32Array
  nextSibling: Int32Array
  depth: Uint8Array
  /** How many nodes a chunk holds, for showing what an expand will cost. */
  nodeCount: Int32Array
}

export type FlattenOptions = {
  /** Id of the first node produced, so ids stay unique across chunks. */
  offset: number
  /** Id of the node these become children of, or -1 for the root. */
  parent: number
  /** Depth of the produced roots. */
  depth: number
}

const MAX_DEPTH = 255 // depth is a Uint8Array

function text(value: unknown): string {
  return typeof value === 'string' ? value : ''
}

export function flatten(roots: readonly RbacTreeNode[], options: FlattenOptions): FlatNodes {
  const { offset } = options

  const texts: string[] = []
  const tags: string[] = []
  const branches: string[] = []
  const chunks: (string | null)[] = []
  const parent: number[] = []
  const firstChild: number[] = []
  const nextSibling: number[] = []
  const depth: number[] = []
  const nodeCount: number[] = []

  // The published tree is cluster > facet > kind > name > rule, so the recursion
  // is bounded by the shape of RBAC rather than by cluster size.
  function walk(node: RbacTreeNode, parentId: number, level: number): number {
    const id = offset + texts.length
    const local = id - offset

    texts.push(text(node.text))
    tags.push(Array.isArray(node.tags) ? node.tags.filter((tag) => text(tag) !== '').join(', ') : '')
    branches.push(text(node.branch))
    chunks.push(typeof node.chunk === 'string' && node.chunk !== '' ? node.chunk : null)
    parent.push(parentId)
    depth.push(Math.min(level, MAX_DEPTH))
    nodeCount.push(typeof node.node_count === 'number' ? node.node_count : 0)
    firstChild.push(-1)
    nextSibling.push(-1)

    let previous = -1
    for (const child of Array.isArray(node.nodes) ? node.nodes : []) {
      const childId = walk(child, id, level + 1)
      if (previous === -1) firstChild[local] = childId
      else nextSibling[previous - offset] = childId
      previous = childId
    }

    return id
  }

  let previousRoot = -1
  for (const root of roots) {
    const id = walk(root, options.parent, options.depth)
    if (previousRoot !== -1) nextSibling[previousRoot - offset] = id
    previousRoot = id
  }

  return {
    count: texts.length,
    texts,
    tags,
    branches,
    chunks,
    parent: Int32Array.from(parent),
    firstChild: Int32Array.from(firstChild),
    nextSibling: Int32Array.from(nextSibling),
    depth: Uint8Array.from(depth),
    nodeCount: Int32Array.from(nodeCount),
  }
}

/** The typed array buffers, for transferring a result out of the worker. */
export function transferables(flat: FlatNodes): ArrayBuffer[] {
  return [flat.parent, flat.firstChild, flat.nextSibling, flat.depth, flat.nodeCount].map(
    (column) => column.buffer as ArrayBuffer,
  )
}
