import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createRouter, createWebHashHistory } from 'vue-router'

import { flatten } from '@/features/tree/flatten'
import { AppError } from '@/lib/api'
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

const SEARCH = {
  chunks: ['index.json', 'namespaces/kube-system.json'],
  terms: { 'default-sa': [1], 'other-sa': [1], 'kube-system': [0] },
}

function fixtureFor(url: string) {
  if (url.endsWith('clusters.json')) return CLUSTERS
  if (url.endsWith('search.json')) return SEARCH
  return { format_version: 1 }
}

const loader: TreeLoader = (request) =>
  Promise.resolve(
    flatten(request.url.endsWith('index.json') ? [INDEX] : [{ text: 'default-sa', tags: ['admits'] }], request),
  )

beforeEach(() => {
  resetClusters()
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) =>
      Promise.resolve(new Response(JSON.stringify(fixtureFor(url)))),
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

  it('explains a branch that the report no longer has', async () => {
    // The report loop prunes chunks its new index does not refer to, so an open
    // page can be holding an index that points at a file that is gone.
    const pruned: TreeLoader = (request) =>
      request.url.endsWith('index.json')
        ? Promise.resolve(flatten([INDEX], request))
        : Promise.reject(new AppError('missing', 'gone'))

    const router = createRouter({
      history: createWebHashHistory(),
      routes: [{ path: '/tree', component: TreeView }],
    })
    await router.push('/tree')
    const wrapper = mount(TreeView, { props: { loader: pruned }, global: { plugins: [router] } })
    await vi.waitFor(() => expect(wrapper.text()).not.toContain('Loading the tree'))

    await wrapper.get('[aria-label="Expand Namespaces"]').trigger('click')
    await wrapper.get('[aria-label="Expand kube-system"]').trigger('click')

    await vi.waitFor(() => expect(wrapper.text()).toContain('regenerated since this page loaded'))
  })

  it('reads the selected path back as a sentence, spaced', async () => {
    const wrapper = await mountView()

    await wrapper.get('[aria-label="Expand Namespaces"]').trigger('click')
    await wrapper.get('[aria-label="Expand kube-system"]').trigger('click')
    await wrapper.findAll('[role="treeitem"] button').at(-1)!.trigger('click')

    const panel = wrapper.get('[aria-label="Selected node"]')
    expect(panel.text()).toContain('Namespace kube-system admits default-sa')
  })

  it('reports names from the index for branches it has not opened', async () => {
    const wrapper = await mountView()

    await wrapper.get('input[type="search"]').setValue('sa')
    await vi.waitFor(() => expect(wrapper.text()).toContain('names match in branches you have not opened'))

    // Two names in the index match, in the one branch holding them: the reader
    // is told about the names, not about the filing.
    expect(wrapper.text()).toContain('2 names match')
    expect(wrapper.text()).not.toContain('branches also contain')
    // And the counter says what its own zero means.
    expect(wrapper.text()).toContain('0 of 0 in open branches')
  })

  it('highlights matches and counts them', async () => {
    const wrapper = await mountView()

    await wrapper.get('input[type="search"]').setValue('kube')
    await vi.waitFor(() => expect(wrapper.text()).toContain('1 of 1'))
    expect(wrapper.get('[role="tree"]').text()).toContain('kube-system')
  })
})
