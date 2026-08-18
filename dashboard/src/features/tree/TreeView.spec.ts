import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createRouter, createWebHashHistory } from 'vue-router'

import { flatten } from '@/features/tree/flatten'
import TreeView from '@/features/tree/TreeView.vue'
import type { TreeLoader } from '@/features/tree/useTree'
import { resetClusters } from '@/lib/cluster'
import type { RbacTreeNode } from '@/lib/types'

const CLUSTERS = { default: 'default', clusters: [{ name: 'default', generated_at: '2026-08-18T09:26:04Z' }] }

const INDEX: RbacTreeNode = {
  text: 'default cluster',
  nodes: [
    {
      text: 'Namespaces',
      nodes: [
        // A node name is a cluster resource name, so it is attacker influenced.
        { text: '<img src=x onerror="alert(1)">', tags: ['Namespace'] },
        { text: 'kube-system', tags: ['Namespace'], chunk: 'namespaces/kube-system.json', node_count: 2 },
      ],
    },
  ],
}

const loader: TreeLoader = (request) =>
  Promise.resolve(
    flatten(request.url.endsWith('index.json') ? [INDEX] : [{ text: 'default-sa' }], request),
  )

beforeEach(() => {
  resetClusters()
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) =>
      Promise.resolve(
        new Response(JSON.stringify(url.endsWith('clusters.json') ? CLUSTERS : { format_version: 1 })),
      ),
    ),
  )
  // The virtualiser renders what fits the scroll element, which it measures
  // with offsetHeight — and happy-dom lays nothing out, so everything is zero.
  for (const [property, value] of [
    ['offsetHeight', 600],
    ['offsetWidth', 800],
  ] as const) {
    Object.defineProperty(HTMLElement.prototype, property, { configurable: true, get: () => value })
  }
})

afterEach(() => {
  for (const property of ['offsetHeight', 'offsetWidth']) {
    Reflect.deleteProperty(HTMLElement.prototype, property)
  }
})

afterEach(() => vi.unstubAllGlobals())

async function mountView() {
  const router = createRouter({
    history: createWebHashHistory(),
    routes: [{ path: '/tree', component: TreeView }],
  })
  await router.push('/tree')
  await router.isReady()

  const wrapper = mount(TreeView, { props: { loader }, global: { plugins: [router] } })
  await vi.waitFor(() => expect(wrapper.text()).not.toContain('Loading the tree'))
  return wrapper
}

describe('TreeView', () => {
  it('renders the loaded rows', async () => {
    const wrapper = await mountView()

    expect(wrapper.findAll('[role="treeitem"]').map((row) => row.text())).toEqual([
      'default cluster',
      'Namespaces',
    ])
    expect(wrapper.text()).toContain('4 nodes loaded')
  })

  it('expands a branch when its chevron is clicked', async () => {
    const wrapper = await mountView()

    await wrapper.get('[aria-label="Expand Namespaces"]').trigger('click')
    await vi.waitFor(() =>
      expect(wrapper.findAll('[role="treeitem"]')).toHaveLength(4),
    )
  })

  it('renders a hostile node name as text', async () => {
    const wrapper = await mountView()

    await wrapper.get('[aria-label="Expand Namespaces"]').trigger('click')
    await vi.waitFor(() => expect(wrapper.text()).toContain('<img src=x onerror="alert(1)">'))
    expect(wrapper.find('img').exists()).toBe(false)
  })

  it('highlights matches and counts them', async () => {
    const wrapper = await mountView()

    await wrapper.get('input[type="search"]').setValue('kube')
    await vi.waitFor(() => expect(wrapper.text()).toContain('1 of 1'))
    expect(wrapper.get('[role="tree"]').text()).toContain('kube-system')
  })
})
