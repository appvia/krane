// Owns the tree: which chunks are loaded, what is expanded, what matched a
// search. The store holds typed arrays that Vue cannot track, so mutations bump
// version counters that everything derived reads through.

import { computed, onScopeDispose, ref, shallowRef, watch } from 'vue'

import { flatten, type FlatNodes } from '@/features/tree/flatten'
import { TreeStore } from '@/features/tree/store'
import { AppError, dataUrl, fetchJson, toAppError } from '@/lib/api'
import { useAsyncData } from '@/lib/async'
import { currentCluster, useCluster } from '@/lib/cluster'
import type { RbacTreeNode, TreeSearchIndex } from '@/lib/types'

const ROOT = -1
const SEARCH_DEBOUNCE_MS = 150

/** Chunk paths come from a published file, and end up in a URL. */
const CHUNK_PATH = /^[a-z0-9][a-z0-9-]*\/[a-z0-9][a-z0-9-]*\.json$/

export type TreeRequest = {
  url: string
  offset: number
  parent: number
  depth: number
}

export type TreeLoader = (request: TreeRequest) => Promise<FlatNodes>

export type TreeRow = {
  id: number
  text: string
  tags: string[]
  depth: number
  expandable: boolean
  expanded: boolean
  loading: boolean
  /** Nodes hidden behind an unloaded chunk, for showing what an expand costs. */
  hidden: number
}

export function chunkUrl(base: string, chunk: string): string {
  if (!CHUNK_PATH.test(chunk)) throw new AppError('malformed', `Refusing to load chunk path "${chunk}"`)
  return `${base}/${chunk}`
}

/** Chunk paths whose contents match the query, from the published search index. */
export function chunksMatching(index: TreeSearchIndex | null, query: string): string[] {
  const needle = query.trim().toLowerCase()
  if (!index || needle === '') return []

  const matched = new Set<number>()
  for (const [term, chunks] of Object.entries(index.terms ?? {})) {
    if (term.includes(needle)) for (const chunk of chunks) matched.add(chunk)
  }

  return [...matched]
    .map((position) => (index.chunks ?? [])[position])
    .filter((path): path is string => typeof path === 'string' && path !== 'index.json')
}

/**
 * Runs flattening in a worker. Falls back to doing it inline if a worker cannot
 * be created — slower, but a tree that renders beats one that does not.
 */
export function createWorkerLoader(): { load: TreeLoader; dispose: () => void } {
  const pending = new Map<number, { resolve: (flat: FlatNodes) => void; reject: (error: unknown) => void }>()
  let worker: Promise<Worker | null> | null = null
  let nextId = 0

  function connect(): Promise<Worker | null> {
    worker ??= import('@/workers/tree.worker.ts?worker')
      .then(({ default: TreeWorker }) => {
        const instance = new TreeWorker()
        instance.onmessage = (event: MessageEvent<{ id: number; flat?: FlatNodes; error?: { kind: string; message: string } }>) => {
          const request = pending.get(event.data.id)
          if (!request) return
          pending.delete(event.data.id)
          const { flat, error } = event.data
          if (flat) request.resolve(flat)
          else request.reject(new AppError((error?.kind ?? 'network') as 'network', error?.message ?? 'Worker failed'))
        }
        return instance
      })
      .catch(() => null)

    return worker
  }

  async function inline(request: TreeRequest): Promise<FlatNodes> {
    const document = await fetchJson<RbacTreeNode>(request.url)
    const roots = request.parent === ROOT ? [document] : (document.nodes ?? [])
    return flatten(roots, request)
  }

  async function load(request: TreeRequest): Promise<FlatNodes> {
    const instance = await connect()
    if (!instance) return inline(request)

    const id = (nextId += 1)
    return new Promise<FlatNodes>((resolve, reject) => {
      pending.set(id, { resolve, reject })
      instance.postMessage({ id, ...request })
    })
  }

  return {
    load,
    dispose: () => void worker?.then((instance) => instance?.terminate()),
  }
}

export function useTree(loader?: TreeLoader) {
  const { requested } = useCluster()

  const worker = loader ? null : createWorkerLoader()
  const load = loader ?? worker!.load
  onScopeDispose(() => worker?.dispose())

  let store = new TreeStore()

  // Two counters rather than one: what has been loaded and what is open change
  // independently, and search results must not depend on the second — opening
  // the way to a match would otherwise invalidate the matches that asked for it.
  const loadedVersion = ref(0)
  const viewVersion = ref(0)
  const bumpLoaded = () => {
    loadedVersion.value += 1
    viewVersion.value += 1
  }
  const bumpView = () => (viewVersion.value += 1)

  const loadingChunks = shallowRef(new Set<string>())
  const chunkError = shallowRef<AppError | null>(null)
  const selected = ref<number | null>(null)

  const query = ref('')
  const applied = ref('')
  const position = ref(0)

  const source = useAsyncData(
    async (signal) => {
      const cluster = await currentCluster(requested.value)
      const base = dataUrl(cluster, 'tree')

      // The manifest is written last, so its presence means every chunk the
      // index refers to is fully on disk.
      await fetchJson(`${base}/manifest.json`, signal)

      const fresh = new TreeStore()
      fresh.graft(ROOT, await load({ url: `${base}/index.json`, offset: 0, parent: ROOT, depth: 0 }))
      for (const root of fresh.roots()) fresh.expand(root)

      // Search can span chunks that were never opened, but only if the index is
      // there. It is optional, so a missing one just narrows search to what is
      // loaded.
      const index = await fetchJson<TreeSearchIndex>(`${base}/search.json`, signal)
        .then((published) =>
          Array.isArray(published?.chunks) && typeof published?.terms === 'object' ? published : null,
        )
        .catch(() => null)

      store = fresh
      selected.value = null
      loadingChunks.value = new Set()
      bumpLoaded()

      return { cluster, base, index }
    },
    { watch: [requested] },
  )

  const rows = computed<TreeRow[]>(() => {
    void viewVersion.value
    const loading = loadingChunks.value

    return store.visible().map((id) => {
      const chunk = store.pendingChunk(id)
      const tags = store.tags[id] ?? ''
      return {
        id,
        text: store.texts[id] ?? '',
        tags: tags === '' ? [] : tags.split(', '),
        depth: store.depth[id] ?? 0,
        expandable: store.hasChildren(id),
        expanded: store.isExpanded(id),
        loading: chunk !== null && loading.has(chunk),
        hidden: chunk === null ? 0 : (store.nodeCount[id] ?? 0),
      }
    })
  })

  const matches = computed(() => {
    void loadedVersion.value
    return store.search(applied.value)
  })

  const current = computed(() => matches.value.ids[position.value] ?? null)

  /** Branches that contain a match but have not been opened yet. */
  const unsearched = computed(() => {
    void loadedVersion.value
    return chunksMatching(source.data.value?.index ?? null, applied.value).filter(
      (chunk) => !store.grafted.has(chunk),
    )
  })

  let debounce: ReturnType<typeof setTimeout> | undefined
  watch(query, (value) => {
    clearTimeout(debounce)
    debounce = setTimeout(() => (applied.value = value), SEARCH_DEBOUNCE_MS)
  })
  onScopeDispose(() => clearTimeout(debounce))

  // Matches are useless if their branches are shut, so open the way to them.
  watch(matches, (found) => {
    position.value = 0
    if (found.ids.length === 0) return
    store.expandAncestors(found.ids)
    bumpView()
  })

  async function fetchChunk(id: number, chunk: string): Promise<void> {
    const base = source.data.value?.base
    if (!base || loadingChunks.value.has(chunk)) return

    loadingChunks.value = new Set(loadingChunks.value).add(chunk)
    chunkError.value = null

    try {
      const flat = await load({
        url: chunkUrl(base, chunk),
        offset: store.nextId,
        parent: id,
        depth: (store.depth[id] ?? 0) + 1,
      })
      store.graft(id, flat)
      store.expand(id)
    } catch (cause) {
      chunkError.value = toAppError(cause)
    } finally {
      const remaining = new Set(loadingChunks.value)
      remaining.delete(chunk)
      loadingChunks.value = remaining
      bumpLoaded()
    }
  }

  async function toggle(id: number): Promise<void> {
    const chunk = store.pendingChunk(id)
    if (chunk) return fetchChunk(id, chunk)

    store.toggle(id)
    bumpView()
  }

  function select(id: number): void {
    selected.value = id
  }

  function collapseAll(): void {
    store.collapseAll()
    for (const root of store.roots()) store.expand(root)
    bumpView()
  }

  /**
   * Loads the unopened branches the search index says contain matches.
   *
   * A chunk can hold references to further chunks, and the node that owns one of
   * those only exists once its parent has been grafted — so this goes round
   * again until nothing new can be reached. The search index lists a match
   * against every chunk on the way to it, which is what makes each pass find
   * the next one.
   */
  async function searchEverywhere(): Promise<void> {
    // Tried, not loaded: a chunk that fails to load stays unsearched, and must
    // not be picked up again on the next pass.
    const attempted = new Set<string>()

    for (;;) {
      const reachable = unsearched.value
        .filter((chunk) => !attempted.has(chunk))
        .map((chunk) => ({ chunk, owner: store.chunks.indexOf(chunk) }))
        .filter((candidate) => candidate.owner !== -1)

      if (reachable.length === 0) return

      for (const { chunk, owner } of reachable) {
        attempted.add(chunk)
        await fetchChunk(owner, chunk)
      }
    }
  }

  function step(by: number): void {
    const { ids } = matches.value
    if (ids.length === 0) return
    position.value = (position.value + by + ids.length) % ids.length
  }

  const details = computed(() => {
    void viewVersion.value
    const id = selected.value
    if (id === null || id >= store.size) return null

    return {
      id,
      text: store.texts[id] ?? '',
      branch: store.branches[id] ?? '',
      tags: store.tags[id] ?? '',
      path: store.ancestors(id).map((ancestor) => store.texts[ancestor] ?? ''),
      children: store.children(id).length,
      hidden: store.nodeCount[id] ?? 0,
      chunk: store.chunks[id],
    }
  })

  return {
    state: source.state,
    error: source.error,
    retry: source.retry,
    cluster: computed(() => source.data.value?.cluster ?? null),
    rows,
    matches,
    current,
    position,
    unsearched,
    query,
    chunkError,
    details,
    selected,
    loadedNodes: computed(() => {
      void loadedVersion.value
      return store.size
    }),
    toggle,
    select,
    collapseAll,
    searchEverywhere,
    next: () => step(1),
    previous: () => step(-1),
  }
}
