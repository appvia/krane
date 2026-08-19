import { describe, expect, it } from 'vitest'

import { flatten } from '@/features/tree/flatten'
import { TreeStore } from '@/features/tree/store'
import type { RbacTreeNode } from '@/lib/types'

const INDEX: RbacTreeNode = {
  text: 'test cluster',
  nodes: [
    {
      text: 'Namespaces',
      nodes: [
        { text: 'kube-system', tags: ['Namespace'], chunk: 'namespaces/kube-system.json', node_count: 3 },
        { text: 'kube-public', tags: ['Namespace'] },
      ],
    },
    { text: 'Actors', nodes: [{ text: 'ServiceAccount', chunk: 'subjects/serviceaccount.json', node_count: 9 }] },
  ],
}

const CHUNK: RbacTreeNode[] = [
  { text: 'default-sa', nodes: [{ text: 'secrets get' }] },
  { text: 'other-sa' },
]

function loaded() {
  const store = new TreeStore()
  store.graft(-1, flatten([INDEX], { offset: 0, parent: -1, depth: 0 }))
  return store
}

// Ids follow the depth first order of INDEX above.
const CLUSTER = 0
const NAMESPACES = 1
const KUBE_SYSTEM = 2
const KUBE_PUBLIC = 3

describe('TreeStore', () => {
  it('shows only the roots until something is expanded', () => {
    const store = loaded()
    expect(store.roots()).toEqual([CLUSTER])
    expect(store.visible()).toEqual([CLUSTER])
  })

  it('walks expanded subtrees in display order', () => {
    const store = loaded()
    store.expand(CLUSTER)
    store.expand(NAMESPACES)

    expect(store.visible().map((id) => store.texts[id])).toEqual([
      'test cluster',
      'Namespaces',
      'kube-system',
      'kube-public',
      'Actors',
    ])
  })

  it('counts a chunk reference as children, because they are only elsewhere', () => {
    const store = loaded()

    expect(store.hasChildren(KUBE_SYSTEM)).toBe(true)
    expect(store.pendingChunk(KUBE_SYSTEM)).toBe('namespaces/kube-system.json')
    expect(store.hasChildren(KUBE_PUBLIC)).toBe(false)
    expect(store.pendingChunk(KUBE_PUBLIC)).toBeNull()
  })

  it('grafts a chunk onto the node that referenced it', () => {
    const store = loaded()
    const offset = store.nextId
    store.graft(KUBE_SYSTEM, flatten(CHUNK, { offset, parent: KUBE_SYSTEM, depth: 3 }))

    expect(store.pendingChunk(KUBE_SYSTEM)).toBeNull()
    expect(store.children(KUBE_SYSTEM).map((id) => store.texts[id])).toEqual(['default-sa', 'other-sa'])
    expect(store.ancestors(offset + 1).map((id) => store.texts[id])).toEqual([
      'test cluster',
      'Namespaces',
      'kube-system',
      'default-sa',
    ])
    expect(store.depth[offset]).toBe(3)
  })

  it('does not refetch a chunk it already holds', () => {
    const store = loaded()
    store.graft(KUBE_SYSTEM, flatten(CHUNK, { offset: store.nextId, parent: KUBE_SYSTEM, depth: 3 }))
    expect(store.grafted.has('namespaces/kube-system.json')).toBe(true)
  })

  it('searches the loaded nodes case insensitively and caps what it returns', () => {
    const store = loaded()

    expect(store.search('KUBE').total).toBe(2)
    expect(store.search('kube').ids.map((id) => store.texts[id])).toEqual(['kube-system', 'kube-public'])
    expect(store.search('  ')).toEqual({ ids: [], total: 0 })
    expect(store.search('e', 1)).toMatchObject({ ids: [CLUSTER], total: 5 })
  })

  it('opens the way to a match', () => {
    const store = loaded()
    store.expandAncestors(store.search('kube-public').ids)

    expect(store.visible().map((id) => store.texts[id])).toContain('kube-public')
  })

  it('grows past its initial capacity', () => {
    const store = loaded()
    const many = Array.from({ length: 3000 }, (_, index) => ({ text: `node-${index}` }))
    store.graft(KUBE_SYSTEM, flatten(many, { offset: store.nextId, parent: KUBE_SYSTEM, depth: 3 }))

    expect(store.size).toBe(3006) // the six index nodes plus the graft
    expect(store.children(KUBE_SYSTEM)).toHaveLength(3000)
    expect(store.texts[store.size - 1]).toBe('node-2999')
    expect(store.parent[store.size - 1]).toBe(KUBE_SYSTEM)
    expect(store.search('node-2999').total).toBe(1)
  })

  it('will not expand a node with nothing under it', () => {
    const store = loaded()
    store.expand(KUBE_PUBLIC)
    expect(store.isExpanded(KUBE_PUBLIC)).toBe(false)
  })

  it('collapses everything at once', () => {
    const store = loaded()
    store.expand(CLUSTER)
    store.expand(NAMESPACES)
    store.collapseAll()

    expect(store.visible()).toEqual([CLUSTER])
  })
})
