import { describe, expect, it } from 'vitest'

import {
  adjacency,
  kindOf,
  matching,
  neighbourhood,
  nodeName,
  orphans,
  resolve,
  tooltip,
} from '@/features/network/graph'
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

const LABELLED: NetworkNode[] = [
  { id: '1', label: 'Namespace: kube-system', group: 0, value: 1, title: '' },
  { id: '2', label: 'Role: view (kube-system)', group: 2, value: 1, title: '' },
  { id: '3', label: 'ClusterRole: view', group: 12, value: 1, title: '' },
  { id: '4', label: 'ServiceAccount: coredns (kube-system)', group: 3, value: 1, title: '' },
]

describe('nodeName', () => {
  it('drops the kind the label is prefixed with', () => {
    expect(nodeName('Namespace: kube-system')).toBe('kube-system')
    // Role names contain colons of their own, so only the first one counts.
    expect(nodeName('ClusterRole: system:controller:attachdetach-controller')).toBe(
      'system:controller:attachdetach-controller',
    )
  })

  it('leaves a label with no kind alone', () => {
    expect(nodeName('unlabelled')).toBe('unlabelled')
  })
})

describe('matching', () => {
  it('searches the whole label, case insensitively', () => {
    expect(matching(LABELLED, 'KUBE-SYSTEM').map((node) => node.id)).toEqual(['1', '2', '4'])
    expect(matching(LABELLED, 'clusterrole').map((node) => node.id)).toEqual(['3'])
  })

  it('caps what it returns, and says nothing for an empty query', () => {
    expect(matching(LABELLED, 'e', 2)).toHaveLength(2)
    expect(matching(LABELLED, '  ')).toEqual([])
  })
})

describe('resolve', () => {
  it('finds the node a name from the tree refers to', () => {
    expect(resolve(LABELLED, 'kube-system').map((node) => node.id)).toEqual(['1'])
    expect(resolve(LABELLED, 'coredns (kube-system)').map((node) => node.id)).toEqual(['4'])
  })

  it('falls back to ignoring the namespace the graph appends', () => {
    // The tree names a namespaced role without the namespace the graph adds.
    const namespaced = LABELLED.filter((node) => node.id !== '3')
    expect(resolve(namespaced, 'view').map((node) => node.id)).toEqual(['2'])
  })

  it('prefers an exact name to the fallback', () => {
    // With a ClusterRole named exactly 'view', the namespaced Role is not a
    // guess worth offering.
    expect(resolve(LABELLED, 'view').map((node) => node.id)).toEqual(['3'])
  })

  it('offers every node answering to the same name rather than picking one', () => {
    const twins: NetworkNode[] = [
      { id: '5', label: 'Role: reader (a)', group: 2, value: 1, title: '' },
      { id: '6', label: 'Role: reader (b)', group: 2, value: 1, title: '' },
    ]
    expect(resolve(twins, 'reader').map((node) => node.id)).toEqual(['5', '6'])
  })

  it('finds nothing for a name that is not there', () => {
    expect(resolve(LABELLED, 'nope')).toEqual([])
    expect(resolve(LABELLED, ' ')).toEqual([])
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
