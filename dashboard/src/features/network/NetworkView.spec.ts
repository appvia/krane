import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createRouter, createWebHashHistory } from 'vue-router'

import NetworkView from '@/features/network/NetworkView.vue'
import type { NetworkFactory, NetworkHandle } from '@/features/network/useVisNetwork'
import { resetClusters } from '@/lib/cluster'

const CLUSTERS = { default: 'default', clusters: [{ name: 'default', generated_at: '2026-08-18T09:26:04Z' }] }

const NETWORK = {
  network_nodes: [
    { id: '1', label: 'Namespace: kube-system', group: 0, value: 4, title: 'Namespace: kube-system' },
    { id: '2', label: 'ServiceAccount: <img src=x onerror="alert(1)">', group: 3, value: 2, title: 'Actor' },
    { id: '3', label: 'Role: view', group: 12, value: 1, title: 'Role: view' },
    { id: '4', label: 'ClusterRole: orphaned', group: 2, value: 1, title: 'Nothing uses this' },
  ],
  network_edges: [
    { from: '1', to: '2' },
    { from: '2', to: '3' },
  ],
}

type Listener = (params: { nodes?: string[]; iterations?: number; total?: number }) => void

/** A stand-in for vis-network: records what it was asked to do. */
function fakeNetwork() {
  const listeners = new Map<string, Listener>()
  const updates: unknown[][] = []
  const calls = { destroyed: 0, fitted: 0, options: [] as Record<string, unknown>[] }
  let handle: NetworkHandle | null = null

  const createNetwork: NetworkFactory = (_container, data, options) => {
    calls.options.push(options)
    const originalUpdate = data.nodes.update.bind(data.nodes)
    data.nodes.update = ((items: unknown) => {
      updates.push(Array.isArray(items) ? items : [items])
      return originalUpdate(items as never)
    }) as typeof data.nodes.update

    handle = {
      on: (event, callback) => listeners.set(event, callback),
      destroy: () => (calls.destroyed += 1),
      fit: () => (calls.fitted += 1),
      setOptions: (options) => calls.options.push(options),
    }
    return handle
  }

  return {
    createNetwork,
    updates,
    calls,
    emit: (event: string, params: Parameters<Listener>[0] = {}) => listeners.get(event)?.(params),
  }
}

beforeEach(() => {
  resetClusters()
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) =>
      Promise.resolve(new Response(JSON.stringify(url.endsWith('clusters.json') ? CLUSTERS : NETWORK))),
    ),
  )
})

afterEach(() => vi.unstubAllGlobals())

async function mountView() {
  const vis = fakeNetwork()
  const router = createRouter({
    history: createWebHashHistory(),
    routes: [{ path: '/network', component: NetworkView }],
  })
  await router.push('/network')
  await router.isReady()

  const wrapper = mount(NetworkView, {
    props: { createNetwork: vis.createNetwork },
    global: { plugins: [router] },
    attachTo: document.body,
  })
  await vi.waitFor(() => expect(wrapper.text()).not.toContain('Loading the graph'))
  return { wrapper, vis }
}

describe('NetworkView', () => {
  it('reports the size of the graph and what is unconnected', async () => {
    const { wrapper } = await mountView()

    expect(wrapper.text()).toContain('4 nodes')
    expect(wrapper.text()).toContain('2 connections')
    expect(wrapper.text()).toContain('1 unconnected')
  })

  it('repaints only the nodes whose highlight changed', async () => {
    const { vis } = await mountView()
    vis.updates.length = 0

    // Focusing node 1 dims node 4: 1, 2 and 3 are within two degrees.
    vis.emit('click', { nodes: ['1'] })
    expect(vis.updates).toHaveLength(1)
    expect(vis.updates[0]?.map((item) => (item as { id: string }).id)).toEqual(['4'])

    // Moving to node 2 changes nothing: the same three stay highlighted.
    vis.emit('click', { nodes: ['2'] })
    expect(vis.updates).toHaveLength(1)

    // Clearing the focus brings back exactly the node that was dimmed.
    vis.emit('click', { nodes: [] })
    expect(vis.updates[1]?.map((item) => (item as { id: string }).id)).toEqual(['4'])
  })

  it('describes the clicked node, as text', async () => {
    const { wrapper, vis } = await mountView()

    vis.emit('click', { nodes: ['2'] })
    await vi.waitFor(() => expect(wrapper.text()).toContain('ServiceAccount:'))

    expect(wrapper.text()).toContain('<img src=x onerror="alert(1)">')
    expect(wrapper.find('img').exists()).toBe(false)
    expect(wrapper.text()).toContain('Connected to 2')
  })

  it('says a node is unconnected rather than leaving the panel blank', async () => {
    const { wrapper, vis } = await mountView()

    vis.emit('click', { nodes: ['4'] })
    await vi.waitFor(() => expect(wrapper.text()).toContain('Nothing is connected to this node.'))
  })

  it('shows layout progress and stops the physics once it settles', async () => {
    const { wrapper, vis } = await mountView()

    expect(wrapper.text()).toContain('Laying out the graph')
    vis.emit('stabilizationProgress', { iterations: 50, total: 200 })
    await vi.waitFor(() => expect(wrapper.text()).toContain('25%'))

    vis.emit('stabilizationIterationsDone')
    await vi.waitFor(() => expect(wrapper.text()).not.toContain('Laying out the graph'))
    expect(vis.calls.options.at(-1)).toEqual({ physics: { enabled: false } })
  })

  it('tears the network down with the view, instead of leaking one per visit', async () => {
    const { wrapper, vis } = await mountView()

    wrapper.unmount()
    expect(vis.calls.destroyed).toBe(1)
  })
})
