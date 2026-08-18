// The cluster to show comes from ?cluster= in the URL, which is user input that
// ends up in a fetch path. It is only ever used after being matched against the
// manifest Ruby publishes, never passed through.

import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { AppError, dataUrl, fetchJson } from '@/lib/api'
import type { ClusterEntry, ClustersManifest } from '@/lib/types'

const manifest = ref<ClustersManifest | null>(null)
let inFlight: Promise<ClustersManifest> | null = null

function normalise(raw: unknown): ClustersManifest {
  const source = (raw ?? {}) as Partial<ClustersManifest>
  const clusters = Array.isArray(source.clusters) ? source.clusters : []
  return {
    default: typeof source.default === 'string' ? source.default : '',
    clusters: clusters.filter((entry): entry is ClusterEntry => typeof entry?.name === 'string'),
  }
}

/** Loads the manifest once and shares it: every view needs it before it can fetch. */
export function loadClusters(): Promise<ClustersManifest> {
  const loaded = manifest.value
  if (loaded) return Promise.resolve(loaded)

  inFlight ??= fetchJson<unknown>(dataUrl('clusters.json'))
    .then((raw) => (manifest.value = normalise(raw)))
    .finally(() => (inFlight = null))

  return inFlight
}

/** Allowlists the requested name, falling back to the published default. */
export function resolveCluster(available: ClustersManifest, requested: string | null): string | null {
  const names = available.clusters.map((entry) => entry.name)
  if (requested !== null && names.includes(requested)) return requested
  if (names.includes(available.default)) return available.default
  return names[0] ?? null
}

/** The cluster a view should load, resolved against the manifest. */
export async function currentCluster(requested: string | null): Promise<string> {
  const cluster = resolveCluster(await loadClusters(), requested)
  if (!cluster) {
    throw new AppError('missing', 'No cluster has been reported on yet. Run `krane report -c CLUSTER` first.')
  }
  return cluster
}

function firstValue(value: unknown): string | null {
  if (typeof value === 'string') return value
  if (Array.isArray(value) && typeof value[0] === 'string') return value[0]
  return null
}

export function useCluster() {
  const route = useRoute()
  const router = useRouter()

  // Fire and forget: whichever view is mounted awaits the same promise through
  // currentCluster() and reports the failure with its own error state.
  void loadClusters().catch(() => undefined)

  const requested = computed(() => firstValue(route.query.cluster))
  const clusters = computed<ClusterEntry[]>(() => manifest.value?.clusters ?? [])
  const cluster = computed(() => (manifest.value ? resolveCluster(manifest.value, requested.value) : null))
  const entry = computed(() => clusters.value.find((item) => item.name === cluster.value) ?? null)

  function select(name: string) {
    void router.push({ ...route, query: { ...route.query, cluster: name } })
  }

  return { cluster, clusters, entry, requested, select }
}
