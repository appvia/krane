<script setup lang="ts">
import { computed } from 'vue'

import { kindOf } from '@/features/network/graph'
import type { NetworkNode } from '@/lib/types'

const props = defineProps<{
  node: NetworkNode | null
  neighbours: NetworkNode[]
  unconnected: NetworkNode[]
  results: NetworkNode[]
  query: string
  hops: number
}>()

defineEmits<{ show: [string] }>()

const kind = computed(() => (props.node ? kindOf(props.node.group) : ''))
</script>

<template>
  <aside
    class="shrink-0 overflow-auto border-border-subtle bg-surface p-5 lg:w-80 lg:border-l"
    aria-label="Graph detail"
  >
    <!-- Searching takes over the panel: the results are what you came for. -->
    <template v-if="query">
      <h2 class="text-sm font-semibold">
        {{ results.length }} {{ results.length === 1 ? 'match' : 'matches' }}
      </h2>
      <p
        v-if="results.length === 0"
        class="mt-2 text-sm text-muted"
      >
        Nothing in the graph is called that.
      </p>
      <ul class="mt-3 space-y-1">
        <li
          v-for="result in results"
          :key="result.id"
        >
          <button
            type="button"
            class="w-full break-words rounded-md px-2 py-1.5 text-left text-sm transition hover:bg-surface-2"
            @click="$emit('show', result.id)"
          >
            {{ result.label }}
          </button>
        </li>
      </ul>
    </template>

    <template v-else-if="node">
      <p class="text-xs font-semibold uppercase tracking-wide text-muted">
        {{ kind }}
      </p>
      <h2 class="mt-1 break-words text-base font-semibold">
        {{ node.label }}
      </h2>
      <p class="mt-2 text-sm text-muted">
        Showing everything within {{ hops }} {{ hops === 1 ? 'hop' : 'hops' }}.
      </p>

      <!-- Interpolated: the title is assembled from cluster RBAC. -->
      <p class="mt-4 whitespace-pre-line text-sm text-muted">
        {{ node.title }}
      </p>

      <p
        v-if="neighbours.length === 0"
        class="mt-4 text-sm text-warning-fg"
      >
        Nothing is connected to this node.
      </p>

      <div
        v-else
        class="mt-5"
      >
        <h3 class="text-sm text-muted">
          Directly connected to {{ neighbours.length }}
        </h3>
        <ul class="mt-2 space-y-1">
          <li
            v-for="neighbour in neighbours"
            :key="neighbour.id"
          >
            <button
              type="button"
              class="w-full break-words rounded-md px-2 py-1.5 text-left text-sm transition hover:bg-surface-2"
              @click="$emit('show', neighbour.id)"
            >
              {{ neighbour.label }}
            </button>
          </li>
        </ul>
      </div>
    </template>

    <!-- Nothing selected: the one thing worth reading off the whole graph is
         what nothing is attached to. -->
    <template v-else>
      <p class="text-sm text-muted">
        Search for a namespace, actor or role, or click a node, to see what it reaches.
      </p>

      <div
        v-if="unconnected.length"
        class="mt-6"
      >
        <h2 class="text-sm font-semibold">
          {{ unconnected.length }} unconnected
        </h2>
        <p class="mt-1 text-sm text-muted">
          Defined, but nothing is bound to them.
        </p>
        <ul class="mt-3 space-y-1">
          <li
            v-for="node_ in unconnected"
            :key="node_.id"
          >
            <button
              type="button"
              class="w-full break-words rounded-md px-2 py-1.5 text-left text-sm text-warning-fg transition hover:bg-surface-2"
              @click="$emit('show', node_.id)"
            >
              {{ node_.label }}
            </button>
          </li>
        </ul>
      </div>
    </template>
  </aside>
</template>
