import { describe, expect, it } from 'vitest'

import { adjacency, changed, kindOf, neighbourhood, orphans, tooltip } from '@/features/network/graph'
import type { NetworkEdge, NetworkNode } from '@/lib/types'

function node(id: string, group = 0): NetworkNode {
  return { id, label: `node ${id}`, group, value: 1, title: `about ${id}` }
}

//  a — b — c — d      e (unconnected)
const NODES = ['a', 'b', 'c', 'd', 'e'].map((id) => node(id))
const EDGES: NetworkEdge[] = [
  { from: 'a', to: 'b' },
  { from: 'b', to: 'c' },
  { from: 'c', to: 'd' },
]

describe('kindOf', () => {
  it('reads the kind out of the ones digit', () => {
    expect(kindOf(0)).toBe('Namespace')
    expect(kindOf(2)).toBe('Role')
    expect(kindOf(3)).toBe('Subject')
  })

  it('ignores the flag boosts Ruby adds to the tens', () => {
    // 12 is a default role, 62 a default aggregable composite one.
    expect(kindOf(12)).toBe('Role')
    expect(kindOf(62)).toBe('Role')
  })
})

describe('adjacency', () => {
  const map = adjacency(NODES, EDGES)

  it('is undirected, so a click works from either end', () => {
    expect([...(map.get('b') ?? [])].sort()).toEqual(['a', 'c'])
  })

  it('gives every node an entry, connected or not', () => {
    expect(map.size).toBe(5)
    expect(map.get('e')?.size).toBe(0)
  })

  it('ignores edges pointing at nodes that were not published', () => {
    const partial = adjacency([node('a')], [{ from: 'a', to: 'ghost' }])
    expect([...(partial.get('a') ?? [])]).toEqual(['ghost'])
    expect(partial.has('ghost')).toBe(false)
  })
})

describe('neighbourhood', () => {
  const map = adjacency(NODES, EDGES)

  it('reaches two degrees out, like the graph always did', () => {
    expect([...neighbourhood(map, 'a')].sort()).toEqual(['a', 'b', 'c'])
  })

  it('can be asked for one degree', () => {
    expect([...neighbourhood(map, 'b', 1)].sort()).toEqual(['a', 'b', 'c'])
    expect([...neighbourhood(map, 'a', 1)].sort()).toEqual(['a', 'b'])
  })

  it('is just the node itself when nothing connects to it', () => {
    expect([...neighbourhood(map, 'e')]).toEqual(['e'])
  })
})

describe('orphans', () => {
  it('finds the nodes nothing is attached to', () => {
    expect(orphans(adjacency(NODES, EDGES))).toEqual(['e'])
  })
})

describe('changed', () => {
  it('reports only what has to be repainted', () => {
    const previous = new Set(['a', 'b', 'c'])
    const next = new Set(['b', 'c', 'd'])

    expect(changed(previous, next).sort()).toEqual(['a', 'd'])
  })

  it('reports nothing when the highlight has not moved', () => {
    const same = new Set(['a', 'b'])
    expect(changed(same, new Set(same))).toEqual([])
  })

  it('reports every dimmed node when the focus is cleared', () => {
    const all = new Set(['a', 'b', 'c', 'd', 'e'])
    expect(changed(neighbourhood(adjacency(NODES, EDGES), 'a'), all).sort()).toEqual(['d', 'e'])
  })
})

describe('tooltip', () => {
  it('builds a text node, so a node title cannot become markup', () => {
    const element = tooltip('Role: <img src=x onerror="alert(1)">\nSecond line', document)

    expect(element.querySelector('img')).toBeNull()
    expect(element.childNodes).toHaveLength(1)
    expect(element.childNodes[0]?.nodeType).toBe(3) // Node.TEXT_NODE
    expect(element.textContent).toBe('Role: <img src=x onerror="alert(1)">\nSecond line')
  })
})
