// Everything about the graph that is not vis-network: who is next to whom, what
// a click should highlight, and what actually changed since the last click.

import type { NetworkEdge, NetworkNode } from '@/lib/types'

/**
 * Ruby encodes the node kind in the ones digit and flags (default, aggregable,
 * composite) in the tens. The flag boosts overlap, so only the kind is decoded.
 */
export const NODE_KINDS = ['Namespace', 'Rule', 'Role', 'Subject', 'Pod security policy'] as const

export type NodeKind = (typeof NODE_KINDS)[number]

export function kindOf(group: number): NodeKind {
  return NODE_KINDS[group % 10] ?? 'Rule'
}

/**
 * One definition of a kind's colour, for both places it is drawn: the canvas
 * reads the token, the legend needs a class Tailwind can see. Splitting them
 * would let the key drift from the dots it explains.
 */
export const KIND_STYLE: Record<NodeKind, { token: string; fallback: string; swatch: string }> = {
  Namespace: { token: '--krane-accent', fallback: '#4f46e5', swatch: 'bg-accent' },
  Rule: { token: '--krane-sev-warning', fallback: '#f79009', swatch: 'bg-warning' },
  Role: { token: '--krane-sev-info', fallback: '#2e90fa', swatch: 'bg-info' },
  Subject: { token: '--krane-sev-success', fallback: '#12b76a', swatch: 'bg-success' },
  'Pod security policy': { token: '--krane-sev-danger', fallback: '#d92d20', swatch: 'bg-danger' },
}

export type Adjacency = Map<string, Set<string>>

export function adjacency(nodes: readonly NetworkNode[], edges: readonly NetworkEdge[]): Adjacency {
  const map: Adjacency = new Map(nodes.map((node) => [node.id, new Set<string>()]))

  for (const edge of edges) {
    map.get(edge.from)?.add(edge.to)
    map.get(edge.to)?.add(edge.from)
  }

  return map
}

/** The node, its neighbours, and their neighbours — the legacy two degrees. */
export function neighbourhood(map: Adjacency, id: string, degrees = 2): Set<string> {
  const found = new Set<string>([id])
  let frontier = [id]

  for (let degree = 0; degree < degrees; degree += 1) {
    const next: string[] = []
    for (const current of frontier) {
      for (const neighbour of map.get(current) ?? []) {
        if (!found.has(neighbour)) {
          found.add(neighbour)
          next.push(neighbour)
        }
      }
    }
    frontier = next
  }

  return found
}

/** Nodes nothing points at: a binding or role that is not doing anything. */
export function orphans(map: Adjacency): string[] {
  return [...map].filter(([, neighbours]) => neighbours.size === 0).map(([id]) => id)
}

/** Labels are published as "Kind: name", with a namespace in brackets for the
 * things that have one: "Role: view (kube-system)".
 */
export function nodeName(label: string): string {
  const separator = label.indexOf(': ')
  return separator === -1 ? label : label.slice(separator + 2)
}

/** Nodes whose label contains the query, for the search box. */
export function matching(nodes: readonly NetworkNode[], query: string, limit = 50): NetworkNode[] {
  const needle = query.trim().toLowerCase()
  if (needle === '') return []

  return nodes.filter((node) => node.label.toLowerCase().includes(needle)).slice(0, limit)
}

/**
 * The graph nodes a name from the tree refers to. The tree names a role without
 * the namespace the graph appends, so that is tried second — and more than one
 * node can answer to a name, in which case the caller has a choice to offer
 * rather than a guess to make.
 */
export function resolve(nodes: readonly NetworkNode[], name: string): NetworkNode[] {
  const wanted = name.trim()
  if (wanted === '') return []

  const exact = nodes.filter((node) => nodeName(node.label) === wanted)
  if (exact.length > 0) return exact

  return nodes.filter((node) => nodeName(node.label).replace(/ \([^)]*\)$/, '') === wanted)
}

/**
 * A tooltip as a text node. vis-network accepts an element or an HTML string,
 * and node titles are built from cluster RBAC — so it gets an element.
 */
export function tooltip(text: string, document: Document): HTMLElement {
  const element = document.createElement('div')
  element.style.whiteSpace = 'pre-wrap'
  element.style.maxWidth = '32rem'
  element.appendChild(document.createTextNode(text))
  return element
}
