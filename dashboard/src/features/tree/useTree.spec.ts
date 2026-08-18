import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { createRouter, createWebHashHistory } from 'vue-router'

import { flatten } from '@/features/tree/flatten'
import { chunkUrl, chunksMatching, useTree, type TreeLoader } from '@/features/tree/useTree'
import { resetClusters } from '@/lib/cluster'
import type { RbacTreeNode, TreeSearchIndex } from '@/lib/types'

const CLUSTERS = { default: 'default', clusters: [{ name: 'default', generated_at: '2026-08-18T09:26:04Z' }] }

const INDEX: RbacTreeNode = {
  text: 'default cluster',
  nodes: [
    {
      text: 'Namespaces',
      nodes: [
        { text: 'kube-system', tags: ['Namespace'], chunk: 'namespaces/kube-system.json', node_count: 3 },
        { text: 'kube-public', tags: ['Namespace'] },
      ],
    },
    {
      text: 'Actors',
      nodes: [{ text: 'ServiceAccount', chunk: 'subjects/serviceaccount.json', node_count: 1 }],
    },
    {
      text: 'Resource Access',
      nodes: [{ text: 'resource', chunk: 'resources/resource.json', node_count: 4 }],
    },
  ],
}

const CHUNKS: Record<string, RbacTreeNode[]> = {
  'namespaces/kube-system.json': [{ text: 'default-sa', nodes: [{ text: 'secrets get' }] }, { text: 'other-sa' }],
  'subjects/serviceaccount.json': [{ text: 'hidden-actor' }],
  // A chunk too big to hand over in one file: its heaviest branch was written to
  // a chunk of its own, which is only reachable once this one is loaded.
  'resources/resource.json': [
    { text: 'configmaps', chunk: 'resources/configmaps.json', node_count: 2 },
    { text: 'endpoints' },
  ],
  'resources/configmaps.json': [{ text: 'get' }, { text: 'watch-buried-verb' }],
}

const SEARCH: TreeSearchIndex = {
  chunks: [
    'index.json',
    'namespaces/kube-system.json',
    'subjects/serviceaccount.json',
    'resources/resource.json',
    'resources/configmaps.json',
  ],
  terms: {
    'kube-system': [0],
    'default-sa': [1],
    'hidden-actor': [2],
    // A term inside a nested chunk is listed against the chunks leading to it,
    // which is what lets search reach it without opening anything by hand.
    'watch-buried-verb': [4, 3],
  },
}

/** Stands in for the worker: same contract, flattened in process. */
function loader(): { load: TreeLoader; calls: string[] } {
  const calls: string[] = []
  const load: TreeLoader = (request) => {
    calls.push(request.url)
    const chunk = Object.keys(CHUNKS).find((path) => request.url.endsWith(path))
    const roots = chunk ? (CHUNKS[chunk] as RbacTreeNode[]) : [INDEX]
    return Promise.resolve(flatten(roots, request))
  }
  return { load, calls }
}

function stubFetch(overrides: Record<string, Response> = {}) {
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) => {
      for (const [suffix, response] of Object.entries(overrides)) {
        if (url.endsWith(suffix)) return Promise.resolve(response)
      }
      if (url.endsWith('clusters.json')) return Promise.resolve(new Response(JSON.stringify(CLUSTERS)))
      if (url.endsWith('manifest.json')) {
        return Promise.resolve(new Response(JSON.stringify({ format_version: 1, generated_at: 'now' })))
      }
      if (url.endsWith('search.json')) return Promise.resolve(new Response(JSON.stringify(SEARCH)))
      return Promise.resolve(new Response('', { status: 404 }))
    }),
  )
}

type Tree = ReturnType<typeof useTree>

async function mountTree(load: TreeLoader) {
  // useTree reads ?cluster= through useCluster, so it needs a router.
  const router = createRouter({
    history: createWebHashHistory(),
    routes: [{ path: '/tree', name: 'tree', component: { template: '<div />' } }],
  })
  await router.push('/tree')
  await router.isReady()

  let tree!: Tree
  const wrapper = mount(
    defineComponent({
      setup() {
        tree = useTree(load)
        return () => h('div')
      },
    }),
    { global: { plugins: [router] } },
  )

  await vi.waitFor(() => expect(tree.state.value).not.toBe('loading'))
  return { tree, wrapper }
}

const texts = (tree: Tree) => tree.rows.value.map((row) => row.text)

beforeEach(() => resetClusters())
afterEach(() => vi.unstubAllGlobals())

describe('useTree', () => {
  it('opens on the index with the root expanded and nothing else fetched', async () => {
    stubFetch()
    const { load, calls } = loader()
    const { tree } = await mountTree(load)

    expect(texts(tree)).toEqual(['default cluster', 'Namespaces', 'Actors', 'Resource Access'])
    expect(calls).toHaveLength(1)
    expect(calls[0]).toContain('data/default/tree/index.json')
    expect(tree.loadedNodes.value).toBe(8)
  })

  it('expands an inlined branch without fetching anything', async () => {
    stubFetch()
    const { load, calls } = loader()
    const { tree } = await mountTree(load)

    await tree.toggle(1) // Namespaces
    expect(texts(tree)).toEqual([
      'default cluster',
      'Namespaces',
      'kube-system',
      'kube-public',
      'Actors',
      'Resource Access',
    ])
    expect(calls).toHaveLength(1)
  })

  it('fetches a chunk the first time its node is expanded, and not again', async () => {
    stubFetch()
    const { load, calls } = loader()
    const { tree } = await mountTree(load)

    await tree.toggle(1)
    await tree.toggle(2) // kube-system, which lives in a chunk

    expect(calls).toHaveLength(2)
    expect(calls[1]).toContain('data/default/tree/namespaces/kube-system.json')
    expect(texts(tree)).toContain('default-sa')
    expect(tree.loadedNodes.value).toBe(11)

    await tree.toggle(2) // collapse
    await tree.toggle(2) // expand again
    expect(calls).toHaveLength(2)
    expect(texts(tree)).toContain('default-sa')
  })

  it('reports what a collapsed chunk is hiding', async () => {
    stubFetch()
    const { load } = loader()
    const { tree } = await mountTree(load)

    await tree.toggle(1)
    expect(tree.rows.value.find((row) => row.text === 'kube-system')?.hidden).toBe(3)
  })

  it('opens the way to a search match and walks the matches', async () => {
    stubFetch()
    const { load } = loader()
    const { tree } = await mountTree(load)

    tree.query.value = 'kube'
    await vi.waitFor(() => expect(tree.matches.value.total).toBe(2))

    expect(texts(tree)).toContain('kube-system')
    expect(tree.current.value).toBe(2)
    tree.next()
    expect(tree.current.value).toBe(3)
    tree.next()
    expect(tree.current.value).toBe(2) // wraps
  })

  it('says which unopened branches also contain matches, and loads them on request', async () => {
    stubFetch()
    const { load } = loader()
    const { tree } = await mountTree(load)

    tree.query.value = 'hidden-actor'
    await vi.waitFor(() => expect(tree.unsearched.value).toEqual(['subjects/serviceaccount.json']))
    expect(tree.matches.value.total).toBe(0)

    await tree.searchEverywhere()
    await vi.waitFor(() => expect(tree.matches.value.total).toBe(1))
    expect(tree.unsearched.value).toEqual([])
    expect(texts(tree)).toContain('hidden-actor')
  })

  it('follows a chunk that points at another chunk', async () => {
    stubFetch()
    const { load, calls } = loader()
    const { tree } = await mountTree(load)

    const row = (text: string) => tree.rows.value.find((candidate) => candidate.text === text)!

    await tree.toggle(row('Resource Access').id)
    await tree.toggle(row('resource').id)

    expect(texts(tree)).toContain('configmaps')
    expect(calls.at(-1)).toContain('resources/resource.json')

    // configmaps arrived holding a reference rather than its children.
    expect(row('configmaps').expandable).toBe(true)
    expect(row('configmaps').hidden).toBe(2)

    await tree.toggle(row('configmaps').id)
    expect(calls.at(-1)).toContain('resources/configmaps.json')
    expect(texts(tree)).toContain('watch-buried-verb')
  })

  it('reaches a match nested two chunks deep, a pass at a time', async () => {
    stubFetch()
    const { load } = loader()
    const { tree } = await mountTree(load)

    tree.query.value = 'watch-buried-verb'
    // Both the chunk holding the match and the one leading to it are unopened.
    await vi.waitFor(() => expect(tree.unsearched.value).toHaveLength(2))
    expect(tree.matches.value.total).toBe(0)

    // The nested chunk's owner does not exist yet, so one call has to load the
    // outer chunk and come back for the inner one.
    await tree.searchEverywhere()

    await vi.waitFor(() => expect(tree.matches.value.total).toBe(1))
    expect(tree.unsearched.value).toEqual([])
    expect(texts(tree)).toContain('watch-buried-verb')
  })

  it('describes the selected node', async () => {
    stubFetch()
    const { load } = loader()
    const { tree } = await mountTree(load)

    await tree.toggle(1)
    tree.select(2)

    expect(tree.details.value).toMatchObject({
      text: 'kube-system',
      tags: 'Namespace',
      path: ['default cluster', 'Namespaces'],
      hidden: 3,
    })
  })

  it('refuses to load without a manifest, because the data may be half written', async () => {
    stubFetch({ 'manifest.json': new Response('', { status: 404 }) })
    const { load, calls } = loader()
    const { tree } = await mountTree(load)

    expect(tree.state.value).toBe('error')
    expect(tree.error.value?.kind).toBe('missing')
    expect(calls).toHaveLength(0)
  })

  it('keeps working without a search index, searching only what is loaded', async () => {
    stubFetch({ 'search.json': new Response('', { status: 404 }) })
    const { load } = loader()
    const { tree } = await mountTree(load)

    tree.query.value = 'kube'
    await vi.waitFor(() => expect(tree.matches.value.total).toBe(0))
    expect(tree.unsearched.value).toEqual([])

    await tree.toggle(1)
    tree.query.value = 'kube-public'
    await vi.waitFor(() => expect(tree.matches.value.total).toBe(1))
  })

  it('surfaces a chunk that fails to load without losing the tree', async () => {
    stubFetch()
    const failing: TreeLoader = (request) =>
      request.url.endsWith('index.json')
        ? Promise.resolve(flatten([INDEX], request))
        : Promise.reject(new Error('chunk is gone'))

    const { tree } = await mountTree(failing)
    await tree.toggle(1)
    await tree.toggle(2)

    expect(tree.chunkError.value?.message).toBe('chunk is gone')
    expect(tree.state.value).toBe('ready')
    expect(texts(tree)).toContain('kube-system')
  })
})

describe('chunkUrl', () => {
  it('joins a published chunk path onto the tree directory', () => {
    expect(chunkUrl('http://host/data/c/tree', 'roles/clusterrole.json')).toBe(
      'http://host/data/c/tree/roles/clusterrole.json',
    )
  })

  it('refuses anything that is not a facet and a slug', () => {
    for (const path of ['../../etc/passwd', '/etc/passwd', 'roles/../../x.json', 'roles/x.json/y', 'x.json']) {
      expect(() => chunkUrl('http://host/data/c/tree', path)).toThrow(/Refusing/)
    }
  })
})

describe('chunksMatching', () => {
  it('finds the chunks whose contents match, ignoring the index itself', () => {
    expect(chunksMatching(SEARCH, 'sa')).toEqual(['namespaces/kube-system.json'])
    expect(chunksMatching(SEARCH, 'KUBE-SYSTEM')).toEqual([])
    expect(chunksMatching(SEARCH, 'actor')).toEqual(['subjects/serviceaccount.json'])
  })

  it('has nothing to say without an index or a query', () => {
    expect(chunksMatching(null, 'sa')).toEqual([])
    expect(chunksMatching(SEARCH, ' ')).toEqual([])
  })
})
