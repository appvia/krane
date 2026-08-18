<script setup lang="ts">
import { Focus, RotateCcw } from 'lucide-vue-next'
import { computed, ref, watch } from 'vue'

import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { NODE_KINDS } from '@/features/network/graph'
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

const { requested } = useCluster()
const { theme } = useTheme()

const canvas = ref<HTMLElement | null>(null)

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

const graph = useVisNetwork(canvas, source.data, props.createNetwork ?? createVisNetwork)

watch(theme, () => graph.retheme())

const counts = computed(() => ({
  nodes: source.data.value?.network_nodes.length ?? 0,
  edges: source.data.value?.network_edges.length ?? 0,
  orphans: graph.orphanCount.value,
}))

const neighbours = computed(() => (graph.selected.value ? graph.neighbours(graph.selected.value.id) : []))
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
            Namespaces, actors and the roles attached to them. Click a node to follow its
            neighbourhood.
          </p>
        </div>

        <div class="flex items-center gap-2">
          <button
            type="button"
            class="flex items-center gap-2 rounded-md border border-border-subtle px-3 py-1.5 text-sm font-medium transition hover:bg-surface-2"
            @click="graph.reset()"
          >
            <RotateCcw
              :size="14"
              aria-hidden="true"
            />
            Clear focus
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
        <span class="tabular-nums">{{ counts.nodes.toLocaleString() }} nodes</span>
        <span class="tabular-nums">{{ counts.edges.toLocaleString() }} connections</span>
        <span
          v-if="counts.orphans"
          class="tabular-nums text-warning-fg"
        >{{ counts.orphans }} unconnected</span>
        <span
          v-for="kind in NODE_KINDS"
          :key="kind"
          class="inline-flex items-center gap-1.5"
        >
          <span
            class="size-2 rounded-full"
            :class="{
              'bg-accent': kind === 'Namespace',
              'bg-warning': kind === 'Rule',
              'bg-info': kind === 'Role',
              'bg-success': kind === 'Subject',
              'bg-danger': kind === 'Pod security policy',
            }"
            aria-hidden="true"
          />
          {{ kind }}
        </span>
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
        :neighbours="neighbours"
        :orphan="neighbours.length === 0 && graph.selected.value !== null"
      />
    </div>
  </section>
</template>
