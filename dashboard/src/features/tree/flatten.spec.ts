import { describe, expect, it } from 'vitest'

import { flatten } from '@/features/tree/flatten'
import type { RbacTreeNode } from '@/lib/types'

const TREE: RbacTreeNode = {
  text: 'test cluster',
  nodes: [
    {
      text: 'Namespaces',
      facet: 'namespaces',
      nodes: [
        {
          branch: 'NAMESPACE',
          text: 'kube-system',
          tags: ['Namespace', ''],
          chunk: 'namespaces/kube-system.json',
          node_count: 382,
        },
        { branch: 'NAMESPACE', text: 'kube-public', tags: ['Namespace'] },
      ],
    },
    { text: 'Actors', facet: 'subjects', nodes: [] },
  ],
}

describe('flatten', () => {
  const flat = flatten([TREE], { offset: 0, parent: -1, depth: 0 })

  it('produces one entry per node, depth first', () => {
    expect(flat.count).toBe(5)
    expect(flat.texts).toEqual(['test cluster', 'Namespaces', 'kube-system', 'kube-public', 'Actors'])
  })

  it('links children through firstChild and nextSibling rather than arrays', () => {
    expect(flat.firstChild[0]).toBe(1) // cluster -> Namespaces
    expect(flat.nextSibling[1]).toBe(4) // Namespaces -> Actors
    expect(flat.firstChild[1]).toBe(2) // Namespaces -> kube-system
    expect(flat.nextSibling[2]).toBe(3) // kube-system -> kube-public
    expect(flat.nextSibling[3]).toBe(-1)
    expect(flat.parent[2]).toBe(1)
    expect(flat.parent[0]).toBe(-1)
  })

  it('records depth', () => {
    expect([...flat.depth]).toEqual([0, 1, 2, 2, 1])
  })

  it('keeps the chunk reference and what it costs to open', () => {
    expect(flat.chunks[2]).toBe('namespaces/kube-system.json')
    expect(flat.nodeCount[2]).toBe(382)
    expect(flat.chunks[3]).toBeNull()
  })

  it('joins tags for display and drops the empty ones', () => {
    expect(flat.tags[2]).toBe('Namespace')
    expect(flat.tags[0]).toBe('')
  })

  it('treats a node with an empty nodes array as a leaf', () => {
    expect(flat.firstChild[4]).toBe(-1)
  })

  it('numbers nodes from the offset it was given, so chunks stay unique', () => {
    const chunk = flatten([{ text: 'a' }, { text: 'b', nodes: [{ text: 'b1' }] }], {
      offset: 100,
      parent: 7,
      depth: 3,
    })

    expect(chunk.parent[0]).toBe(7) // roots hang off the node being expanded
    expect(chunk.nextSibling[0]).toBe(101)
    expect(chunk.firstChild[1]).toBe(102)
    expect(chunk.parent[2]).toBe(101)
    expect([...chunk.depth]).toEqual([3, 3, 4])
  })

  it('survives a node with nothing in it', () => {
    const flat = flatten([{}], { offset: 0, parent: -1, depth: 0 })
    expect(flat.texts).toEqual([''])
    expect(flat.chunks).toEqual([null])
  })
})
