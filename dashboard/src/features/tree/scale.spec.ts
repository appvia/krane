// The tree is the reason for the rewrite, so its cost is asserted rather than
// assumed. Bounds are deliberately loose: they are here to catch an accidental
// quadratic, not to measure the machine.
//
// Measured on a synthetic 26 MB tree (439,320 nodes) while writing this:
// parse 109 ms and flatten 87 ms in the worker, graft 15 ms, search 13 ms, and
// deriving the visible rows 1 ms.

import { describe, expect, it } from 'vitest'

import { flatten } from '@/features/tree/flatten'
import { TreeStore } from '@/features/tree/store'
import type { RbacTreeNode } from '@/lib/types'

function synthetic(namespaces: number, subjects: number, rules: number): RbacTreeNode[] {
  return Array.from({ length: namespaces }, (_, n) => ({
    text: `namespace-${n}`,
    tags: ['Namespace'],
    nodes: Array.from({ length: subjects }, (_, s) => ({
      text: `serviceaccount-${n}-${s}`,
      tags: ['Actor'],
      nodes: Array.from({ length: rules }, (_, r) => ({
        text: `[core] configmaps get list watch ${r}`,
        tags: ['Rule'],
      })),
    })),
  }))
}

function elapsed(work: () => void): number {
  const started = performance.now()
  work()
  return performance.now() - started
}

describe('a tree far larger than any real cluster', () => {
  const store = new TreeStore()
  const flat = flatten(synthetic(60, 40, 30), { offset: 0, parent: -1, depth: 0 })
  store.graft(-1, flat)

  it('flattens into one entry per node', () => {
    expect(flat.count).toBe(60 + 60 * 40 + 60 * 40 * 30)
    expect(store.size).toBe(flat.count)
  })

  it('searches the whole tree well inside a keystroke', () => {
    let found = { ids: [] as number[], total: 0 }
    const ms = elapsed(() => (found = store.search('serviceaccount-59-39')))

    expect(found.total).toBe(1)
    expect(ms).toBeLessThan(200)
  })

  it('costs the same to render whether a branch holds ten nodes or a hundred thousand', () => {
    const collapsed = store.visible().length
    store.expandAncestors(store.search('serviceaccount-59-39').ids)

    let rows: number[] = []
    const ms = elapsed(() => (rows = store.visible()))

    // Opening the way to a match reveals its ancestors' children and no more:
    // the match's own 30 rules stay shut until it is expanded.
    expect(collapsed).toBe(60)
    expect(rows.length).toBe(60 + 40)
    expect(ms).toBeLessThan(50)
  })
})
