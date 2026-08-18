import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createRouter, createWebHashHistory } from 'vue-router'

import NetworkView from '@/features/network/NetworkView.vue'
import type { NetworkFactory } from '@/features/network/useVisNetwork'
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

/** A stand-in for vis-network: records what it was handed and asked to do. */
function fakeNetwork() {
  const listeners = new Map<string, Listener>()
  const drawn: { nodes: string[]; edges: string[] }[] = []
  const calls = { destroyed: 0, fitted: 0, options: [] as Record<string, unknown>[] }

  const createNetwork: NetworkFactory = (_container, data, options) => {
    calls.options.push(options)
    drawn.push({
      nodes: data.nodes.getIds().map(String),
      edges: data.edges.getIds().map(String),
    })

    return {
      on: (event, callback) => listeners.set(event, callback),
      destroy: () => (calls.destroyed += 1),
      fit: () => (calls.fitted += 1),
      setOptions: (settings) => calls.options.push(settings),
    }
  }

  return {
    createNetwork,
    drawn,
    latest: () => drawn[drawn.length - 1],
    calls,
    emit: (event: string, params: Parameters<Listener>[0] = {}) => listeners.get(event)?.(params),
  }
}

// Same name in two namespaces, which the tree cannot tell apart.
const AMBIGUOUS = {
  network_nodes: [
    ...NETWORK.network_nodes,
    { id: '5', label: 'Role: ambiguous (kube-system)', group: 2, value: 1, title: 'One' },
    { id: '6', label: 'Role: ambiguous (default)', group: 2, value: 1, title: 'Two' },
  ],
  network_edges: NETWORK.network_edges,
}

let fixture: typeof NETWORK = NETWORK

beforeEach(() => {
  fixture = NETWORK
  resetClusters()
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) =>
      Promise.resolve(new Response(JSON.stringify(url.endsWith('clusters.json') ? CLUSTERS : fixture))),
    ),
  )
})

afterEach(() => vi.unstubAllGlobals())

async function mountView(query: Record<string, string> = {}) {
  const vis = fakeNetwork()
  const router = createRouter({
    history: createWebHashHistory(),
    routes: [{ path: '/network', name: 'network', component: NetworkView }],
  })
  await router.push({ name: 'network', query })
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

  it('draws only the neighbourhood of the node clicked', async () => {
    const { wrapper, vis } = await mountView()

    expect(vis.latest()?.nodes).toEqual(['1', '2', '3', '4'])

    // Node 4 is unconnected, so it is not within any number of hops of node 1.
    vis.emit('click', { nodes: ['1'] })
    await vi.waitFor(() => expect(vis.latest()?.nodes).toEqual(['1', '2', '3']))
    expect(vis.latest()?.edges).toEqual(['1->2', '2->3'])
    expect(wrapper.text()).toContain('3 of 4 nodes')
  })

  it('narrows to fewer hops on request', async () => {
    const { wrapper, vis } = await mountView()

    vis.emit('click', { nodes: ['1'] })
    await vi.waitFor(() => expect(vis.latest()?.nodes).toHaveLength(3))

    await wrapper.get('select').setValue('1')
    await vi.waitFor(() => expect(vis.latest()?.nodes).toEqual(['1', '2']))
  })

  it('goes back to the whole graph', async () => {
    const { wrapper, vis } = await mountView()

    vis.emit('click', { nodes: ['1'] })
    await vi.waitFor(() => expect(vis.latest()?.nodes).toHaveLength(3))

    await wrapper.get('button[type="button"]').trigger('click') // Whole graph
    await vi.waitFor(() => expect(vis.latest()?.nodes).toHaveLength(4))
  })

  it('describes the clicked node, as text', async () => {
    const { wrapper, vis } = await mountView()

    vis.emit('click', { nodes: ['2'] })
    await vi.waitFor(() => expect(wrapper.text()).toContain('ServiceAccount:'))

    expect(wrapper.text()).toContain('<img src=x onerror="alert(1)">')
    expect(wrapper.find('img').exists()).toBe(false)
    expect(wrapper.text()).toContain('Directly connected to 2')
  })

  it('lists what nothing is bound to while nothing is selected', async () => {
    const { wrapper } = await mountView()

    expect(wrapper.text()).toContain('1 unconnected')
    expect(wrapper.text()).toContain('ClusterRole: orphaned')
  })

  it('says a node is unconnected rather than leaving the panel blank', async () => {
    const { wrapper, vis } = await mountView()

    vis.emit('click', { nodes: ['4'] })
    await vi.waitFor(() => expect(wrapper.text()).toContain('Nothing is connected to this node.'))
  })

  it('opens on the node the tree sent it to', async () => {
    // The tree links by the name in front of the reader, not by an id.
    const { wrapper, vis } = await mountView({ focus: 'kube-system' })

    await vi.waitFor(() => expect(vis.latest()?.nodes).toEqual(['1', '2', '3']))
    expect(wrapper.text()).toContain('Namespace: kube-system')
  })

  it('offers the choice when a name means more than one node', async () => {
    fixture = AMBIGUOUS
    const { wrapper, vis } = await mountView({ focus: 'ambiguous' })

    // Two nodes answer to it, so the search is filled in rather than guessed at.
    await vi.waitFor(() => expect(wrapper.text()).toContain('2 matches'))
    expect(vis.latest()?.nodes).toHaveLength(6) // still the whole graph
  })

  it('searches by label and focuses what is picked', async () => {
    const { wrapper, vis } = await mountView()

    await wrapper.get('input[type="search"]').setValue('serviceaccount')
    expect(wrapper.text()).toContain('1 match')

    await wrapper.get('aside button').trigger('click')
    // Drawn outward from the node picked, so the order follows the hops.
    await vi.waitFor(() => expect(vis.latest()?.nodes).toEqual(['2', '1', '3']))
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
