<script setup lang="ts">
import { Focus, Search, X } from 'lucide-vue-next'
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { matching, resolve } from '@/features/network/graph'
import NodeDetailsPanel from '@/features/network/NodeDetailsPanel.vue'
import { useVisNetwork, type NetworkFactory } from '@/features/network/useVisNetwork'
import { createVisNetwork } from '@/features/network/visNetwork'
import { dataUrl, fetchJson } from '@/lib/api'
import { useAsyncData } from '@/lib/async'
import { currentCluster, useCluster } from '@/lib/cluster'
import { useTheme } from '@/lib/theme'
import type { NetworkData } from '@/lib/types'

// Injectable so tests do not need a canvas.
const props = defineProps<{ createNetwork?: NetworkFactory }>()

const HOPS = [1, 2, 3]

const route = useRoute()
const router = useRouter()
const { requested } = useCluster()
const { theme } = useTheme()

const canvas = ref<HTMLElement | null>(null)
const focus = ref<string | null>(null)
const degrees = ref(2)
const query = ref('')

const source = useAsyncData<NetworkData>(
  async (signal) => {
    const cluster = await currentCluster(requested.value)
    return fetchJson<NetworkData>(dataUrl(cluster, 'rbac-network.json'), signal)
  },
  {
    isEmpty: (data) => (data.network_nodes ?? []).length === 0,
    watch: [requested],
  },
)

const graph = useVisNetwork(canvas, source.data, focus, degrees, props.createNetwork ?? createVisNetwork)

watch(theme, () => graph.retheme())

const results = computed(() => matching(graph.nodes.value, query.value))

// The tree links here by name, which is what a reader has in front of them; more
// than one node can answer to it, and then the choice is theirs.
watch(
  [() => route.query.focus, graph.nodes],
  ([wanted, nodes]) => {
    const name = Array.isArray(wanted) ? wanted[0] : wanted
    if (typeof name !== 'string' || name === '' || nodes.length === 0) return

    const found = resolve(nodes, name)
    if (found.length === 1) focus.value = found[0]?.id ?? null
    else if (found.length > 1) query.value = name
  },
  { immediate: true },
)

function show(id: string) {
  focus.value = id
  query.value = ''
}

function clear() {
  focus.value = null
  query.value = ''
  // Otherwise coming back to this view refocuses whatever the tree sent.
  if (route.query.focus !== undefined) {
    void router.replace({ ...route, query: { ...route.query, focus: undefined } })
  }
}

const counts = computed(() => ({
  nodes: source.data.value?.network_nodes.length ?? 0,
  edges: source.data.value?.network_edges.length ?? 0,
}))

// Assembled here rather than in the template: text split across elements picks
// up whatever whitespace the formatter leaves behind.
const shown = computed(() => {
  const total = counts.value.nodes.toLocaleString()
  return focus.value === null ? `${total} nodes` : `${graph.drawn.value.toLocaleString()} of ${total} nodes`
})
</script>

<template>
  <section class="flex h-full flex-col">
    <header class="shrink-0 border-b border-border-subtle p-6 pb-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 class="text-xl font-semibold tracking-tight">
            RBAC graph
          </h1>
          <p class="mt-1 text-sm text-muted">
            Namespaces, actors and the roles attached to them. Search for one to see what it
            reaches; click a node to move the view onto it.
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-2">
          <label class="relative">
            <Search
              :size="15"
              class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted"
              aria-hidden="true"
            />
            <input
              v-model="query"
              type="search"
              placeholder="Search the graph"
              aria-label="Search the graph"
              class="w-56 rounded-md border border-border-subtle bg-surface py-1.5 pl-9 pr-3 text-sm placeholder:text-muted"
            >
          </label>

          <label class="flex items-center gap-2 text-sm text-muted">
            Hops
            <select
              v-model.number="degrees"
              aria-label="How many hops to show"
              class="rounded-md border border-border-subtle bg-surface px-2 py-1.5 text-sm text-content"
            >
              <option
                v-for="hop in HOPS"
                :key="hop"
                :value="hop"
              >
                {{ hop }}
              </option>
            </select>
          </label>

          <button
            v-if="focus"
            type="button"
            class="flex items-center gap-2 rounded-md border border-border-subtle px-3 py-1.5 text-sm font-medium transition hover:bg-surface-2"
            @click="clear"
          >
            <X
              :size="14"
              aria-hidden="true"
            />
            Whole graph
          </button>
          <button
            type="button"
            class="flex items-center gap-2 rounded-md border border-border-subtle px-3 py-1.5 text-sm font-medium transition hover:bg-surface-2"
            @click="graph.fit()"
          >
            <Focus
              :size="14"
              aria-hidden="true"
            />
            Fit
          </button>
        </div>
      </div>

      <p class="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted">
        <span class="tabular-nums">{{ shown }}</span>
        <span class="tabular-nums">{{ counts.edges.toLocaleString() }} connections</span>
        <span
          v-if="graph.orphanCount.value"
          class="tabular-nums text-warning-fg"
        >{{ graph.orphanCount.value }} unconnected</span>
      </p>
    </header>

    <LoadingState
      v-if="source.state.value === 'loading'"
      label="Loading the graph…"
    />

    <ErrorState
      v-else-if="source.state.value === 'error'"
      :error="source.error.value"
      @retry="source.retry()"
    />

    <div
      v-else
      class="flex min-h-0 flex-1 flex-col lg:flex-row"
    >
      <div class="relative min-h-0 flex-1">
        <!-- Full height rather than the old fixed 900px. -->
        <div
          ref="canvas"
          class="absolute inset-0"
          aria-label="RBAC graph"
          role="img"
        />
        <div
          v-if="graph.stabilizing.value"
          class="absolute inset-x-0 top-0 p-4"
        >
          <p class="text-xs text-muted">
            Laying out the graph… {{ graph.progress.value }}%
          </p>
          <div class="mt-1 h-1 w-full overflow-hidden rounded bg-surface-2">
            <div
              class="h-full bg-accent transition-[width]"
              :style="{ width: `${graph.progress.value}%` }"
            />
          </div>
        </div>
      </div>

      <NodeDetailsPanel
        :node="graph.selected.value"
        :neighbours="graph.neighbours.value"
        :unconnected="graph.unconnected.value"
        :results="results"
        :query="query"
        :hops="degrees"
        @show="show"
      />
    </div>
  </section>
</template>
