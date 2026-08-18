<script setup lang="ts">
import { computed } from 'vue'

import { kindOf } from '@/features/network/graph'
import type { NetworkNode } from '@/lib/types'

const props = defineProps<{ node: NetworkNode | null; neighbours: string[]; orphan: boolean }>()

const kind = computed(() => (props.node ? kindOf(props.node.group) : ''))
</script>

<template>
  <aside
    class="shrink-0 overflow-auto border-border-subtle bg-surface p-5 lg:w-80 lg:border-l"
    aria-label="Selected node"
  >
    <p
      v-if="!node"
      class="text-sm text-muted"
    >
      Click a node to follow what it is connected to.
    </p>

    <template v-else>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted">
        {{ kind }}
      </p>
      <h2 class="mt-1 break-words text-base font-semibold">
        {{ node.label }}
      </h2>
      <p
        v-if="orphan"
        class="mt-2 text-sm text-warning-fg"
      >
        Nothing is connected to this node.
      </p>

      <!-- Interpolated: the title is assembled from cluster RBAC. -->
      <p class="mt-4 whitespace-pre-line text-sm text-muted">
        {{ node.title }}
      </p>

      <div
        v-if="neighbours.length"
        class="mt-5"
      >
        <h3 class="text-sm text-muted">
          Connected to {{ neighbours.length }}
        </h3>
        <ul class="mt-2 space-y-1 text-sm">
          <li
            v-for="neighbour in neighbours"
            :key="neighbour"
            class="break-words"
          >
            {{ neighbour }}
          </li>
        </ul>
      </div>
    </template>
  </aside>
</template>
