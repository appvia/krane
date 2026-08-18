// Owns the vis-network instance: created on mount, destroyed with the scope.
//
// The graph draws one neighbourhood at a time rather than the whole cluster.
// Everything at once is a hairball on any cluster big enough to need help — and
// the questions worth asking of RBAC are local: what can this subject reach, and
// what is attached to this role.

import { DataSet } from 'vis-data'
import { computed, onScopeDispose, ref, watch, type Ref } from 'vue'

import { adjacency, kindOf, neighbourhood, orphans, tooltip } from '@/features/network/graph'
import type { NetworkData, NetworkNode } from '@/lib/types'

const FIT_THROTTLE_MS = 200

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
  edge: string
  border: string
  font: string
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
    edge: token('--krane-border', '#e2e8f0'),
    border: token('--krane-surface', '#ffffff'),
    font: token('--krane-text', '#0f172a'),
    orphan: token('--krane-sev-warning', '#f79009'),
  }
}

function paint(node: NetworkNode, colours: Palette, isOrphan: boolean, isFocus: boolean) {
  const base = colours.kinds[kindOf(node.group)] ?? colours.edge
  return {
    color: {
      background: base,
      border: isOrphan ? colours.orphan : isFocus ? colours.font : base,
      highlight: { background: base, border: colours.font },
    },
    borderWidth: isOrphan || isFocus ? 3 : 1,
    font: { color: colours.font },
  }
}

export function useVisNetwork(
  container: Ref<HTMLElement | null>,
  data: Ref<NetworkData | null>,
  focus: Ref<string | null>,
  degrees: Ref<number>,
  createNetwork: NetworkFactory,
) {
  const stabilizing = ref(false)
  const progress = ref(0)

  let network: NetworkHandle | null = null
  let colours = palette()

  // Everything about the graph is derived from the published data, so it is
  // derived rather than rebuilt into fields: a plain field assigned inside the
  // render would leave the panel reading a map that no longer exists.
  const nodes = computed(() => data.value?.network_nodes ?? [])
  const edges = computed(() => data.value?.network_edges ?? [])
  const byId = computed(() => new Map(nodes.value.map((node) => [node.id, node])))
  const links = computed(() => adjacency(nodes.value, edges.value))
  const orphaned = computed(() => new Set(orphans(links.value)))

  /** The nodes on screen: one neighbourhood, or everything when nothing is picked. */
  const visible = computed(() =>
    focus.value !== null && byId.value.has(focus.value)
      ? neighbourhood(links.value, focus.value, degrees.value)
      : new Set(byId.value.keys()),
  )

  const selected = computed(() => (focus.value === null ? null : (byId.value.get(focus.value) ?? null)))

  const neighbours = computed(() => {
    if (focus.value === null) return []
    return [...(links.value.get(focus.value) ?? [])]
      .map((id) => byId.value.get(id))
      .filter((node): node is NetworkNode => node !== undefined)
  })

  const unconnected = computed(() =>
    [...orphaned.value].map((id) => byId.value.get(id)).filter((node): node is NetworkNode => node !== undefined),
  )

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

    colours = palette()
    const drawn = visible.value

    const shown = new DataSet(
      [...drawn].map((id) => byId.value.get(id) as NetworkNode).map((node) => ({
        ...node,
        // An element, not an HTML string: titles are built from RBAC.
        title: tooltip(node.title, document) as unknown as string,
        ...paint(node, colours, orphaned.value.has(node.id), node.id === focus.value),
      })),
    )

    const drawnEdges = new DataSet([
      ...new Map(
        source.network_edges
          .filter((edge) => drawn.has(edge.from) && drawn.has(edge.to))
          .map((edge) => [`${edge.from}->${edge.to}`, { id: `${edge.from}->${edge.to}`, ...edge }]),
      ).values(),
    ])

    stabilizing.value = true
    progress.value = 0

    network = createNetwork(element, { nodes: shown, edges: drawnEdges }, {
      nodes: {
        shape: 'dot',
        scaling: { min: 8, max: 32, label: { min: 10, max: 22, drawThreshold: 10, maxVisible: 24 } },
      },
      edges: {
        width: 0.6,
        selectionWidth: 3,
        color: { color: colours.edge, highlight: colours.font, inherit: false },
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

    // Clicking walks the graph: the node clicked becomes the new centre.
    network.on('click', (params) => {
      const clicked = params.nodes?.[0]
      if (clicked !== undefined) focus.value = clicked
    })

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
  watch([container, data, focus, degrees], build, { flush: 'post' })

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
    neighbours,
    unconnected,
    nodes,
    drawn: computed(() => visible.value.size),
    orphanCount: computed(() => orphaned.value.size),
    /** Re-reads the theme tokens and redraws. */
    retheme: build,
    fit: () => network?.fit(),
  }
}
