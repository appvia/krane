// Owns the vis-network instance: created on mount, destroyed with the scope.
// The old graph leaked one Network per navigation, and repainted every node on
// every click; this repaints only what changed.

import { DataSet } from 'vis-data'
import { computed, onScopeDispose, ref, shallowRef, watch, type Ref } from 'vue'

import { adjacency, changed, kindOf, neighbourhood, orphans, tooltip } from '@/features/network/graph'
import type { NetworkData, NetworkNode } from '@/lib/types'

const FIT_THROTTLE_MS = 200
const HIGHLIGHT_DEGREES = 2

/** What this needs from vis-network, so tests can hand it something simpler. */
export type NetworkHandle = {
  on(event: string, callback: (params: { nodes?: string[]; iterations?: number; total?: number }) => void): void
  destroy(): void
  fit(): void
  setOptions(options: Record<string, unknown>): void
}

/** vis-data keys everything by id, and published edges carry none. */
type EdgeItem = { id: string; from: string; to: string }

export type NetworkFactory = (
  container: HTMLElement,
  data: { nodes: DataSet<NetworkNode>; edges: DataSet<EdgeItem> },
  options: Record<string, unknown>,
) => NetworkHandle

type Palette = {
  kinds: Record<string, string>
  dim: string
  border: string
  font: string
  dimFont: string
  orphan: string
}

/** Colours come from the theme tokens, so the graph re-themes with everything else. */
function palette(): Palette {
  const styles = getComputedStyle(document.documentElement)
  const token = (name: string, fallback: string) => styles.getPropertyValue(name).trim() || fallback

  return {
    kinds: {
      Namespace: token('--krane-accent', '#4f46e5'),
      Rule: token('--krane-sev-warning', '#f79009'),
      Role: token('--krane-sev-info', '#2e90fa'),
      Subject: token('--krane-sev-success', '#12b76a'),
      'Pod security policy': token('--krane-sev-danger', '#d92d20'),
    },
    dim: token('--krane-border', '#e2e8f0'),
    border: token('--krane-surface', '#ffffff'),
    font: token('--krane-text', '#0f172a'),
    dimFont: token('--krane-muted', '#64748b'),
    orphan: token('--krane-sev-warning', '#f79009'),
  }
}

function paint(node: NetworkNode, colours: Palette, highlighted: boolean, isOrphan: boolean) {
  const base = colours.kinds[kindOf(node.group)] ?? colours.dim
  return {
    id: node.id,
    color: {
      background: highlighted ? base : colours.dim,
      border: isOrphan ? colours.orphan : highlighted ? base : colours.dim,
      highlight: { background: base, border: colours.orphan },
    },
    borderWidth: isOrphan ? 3 : 1,
    font: { color: highlighted ? colours.font : colours.dimFont },
  }
}

export function useVisNetwork(
  container: Ref<HTMLElement | null>,
  data: Ref<NetworkData | null>,
  createNetwork: NetworkFactory,
) {
  const stabilizing = ref(false)
  const progress = ref(0)
  const selected = shallowRef<NetworkNode | null>(null)
  const orphaned = shallowRef(new Set<string>())

  let network: NetworkHandle | null = null
  let nodes: DataSet<NetworkNode> | null = null
  let byId = new Map<string, NetworkNode>()
  let links = adjacency([], [])

  /** Currently undimmed nodes; everything else is greyed out. */
  let highlighted = new Set<string>()
  let colours = palette()

  function repaint(ids: Iterable<string>) {
    if (!nodes) return
    const updates = []
    for (const id of ids) {
      const node = byId.get(id)
      if (node) updates.push(paint(node, colours, highlighted.has(id), orphaned.value.has(id)))
    }
    if (updates.length > 0) nodes.update(updates)
  }

  function focus(id: string | null) {
    const next = id === null ? new Set(byId.keys()) : neighbourhood(links, id, HIGHLIGHT_DEGREES)
    const difference = changed(highlighted, next)
    highlighted = next
    repaint(difference)
    selected.value = id === null ? null : (byId.get(id) ?? null)
  }

  // A graph laid out for a narrow pane is unreadable once the pane grows.
  let fitTimer: ReturnType<typeof setTimeout> | undefined
  let observer: ResizeObserver | null = null

  function observe(element: HTMLElement) {
    if (typeof ResizeObserver === 'undefined') return
    observer?.disconnect()
    observer = new ResizeObserver(() => {
      clearTimeout(fitTimer)
      fitTimer = setTimeout(() => network?.fit(), FIT_THROTTLE_MS)
    })
    observer.observe(element)
  }

  function build() {
    const element = container.value
    const source = data.value
    if (!element || !source) return

    network?.destroy()
    observe(element)

    byId = new Map(source.network_nodes.map((node) => [node.id, node]))
    links = adjacency(source.network_nodes, source.network_edges)
    orphaned.value = new Set(orphans(links))
    highlighted = new Set(byId.keys())
    colours = palette()

    nodes = new DataSet(
      source.network_nodes.map((node) => ({
        ...node,
        // An element, not an HTML string: titles are built from RBAC.
        title: tooltip(node.title, document) as unknown as string,
        ...paint(node, colours, true, orphaned.value.has(node.id)),
      })),
    )
    // Keyed by the pair, which also drops any duplicates in the published data.
    const edges = new DataSet([
      ...new Map(
        source.network_edges.map((edge) => [`${edge.from}->${edge.to}`, { id: `${edge.from}->${edge.to}`, ...edge }]),
      ).values(),
    ])

    stabilizing.value = true
    progress.value = 0

    network = createNetwork(element, { nodes, edges }, {
      nodes: {
        shape: 'dot',
        scaling: { min: 8, max: 32, label: { min: 10, max: 22, drawThreshold: 10, maxVisible: 24 } },
      },
      edges: {
        width: 0.4,
        selectionWidth: 3,
        color: { color: colours.dim, highlight: colours.dimFont, inherit: false },
        smooth: { type: 'continuous' },
      },
      layout: { improvedLayout: false },
      physics: {
        solver: 'forceAtlas2Based',
        forceAtlas2Based: { centralGravity: 0.01, springLength: 200, springConstant: 0.3, damping: 0.09 },
        stabilization: { enabled: true, iterations: 200, updateInterval: 25, fit: true },
      },
      interaction: { tooltipDelay: 200, hideEdgesOnDrag: true, hideEdgesOnZoom: true },
    })

    network.on('click', (params) => focus(params.nodes?.[0] ?? null))

    network.on('stabilizationProgress', (params) => {
      progress.value = params.total ? Math.round(((params.iterations ?? 0) / params.total) * 100) : 0
    })

    // Physics is only needed to lay the graph out. Left running it burns a core
    // for as long as the tab is open.
    network.on('stabilizationIterationsDone', () => {
      stabilizing.value = false
      progress.value = 100
      network?.setOptions({ physics: { enabled: false } })
    })
  }

  // The container only exists once the data has loaded and the view has
  // rendered, so both are watched, after the DOM update rather than before it.
  watch([container, data], build, { flush: 'post' })

  onScopeDispose(() => {
    clearTimeout(fitTimer)
    observer?.disconnect()
    network?.destroy()
    network = null
  })

  return {
    stabilizing,
    progress,
    selected,
    orphanCount: computed(() => orphaned.value.size),
    neighbours: (id: string) => [...(links.get(id) ?? [])].map((neighbour) => byId.get(neighbour)?.label ?? neighbour),
    /** Re-reads the theme tokens and repaints every node. */
    retheme: () => {
      colours = palette()
      repaint(byId.keys())
    },
    reset: () => focus(null),
    fit: () => network?.fit(),
  }
}
