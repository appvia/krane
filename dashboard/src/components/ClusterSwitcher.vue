<script setup lang="ts">
import { Boxes } from 'lucide-vue-next'

import { useCluster } from '@/lib/cluster'
import { formatTimestamp } from '@/lib/format'

const { cluster, clusters, entry, select } = useCluster()
</script>

<template>
  <div class="flex min-w-0 items-center gap-3">
    <Boxes
      :size="18"
      class="shrink-0 text-muted"
      aria-hidden="true"
    />

    <!-- One cluster is the common case, and a dropdown of one is just noise. -->
    <span
      v-if="clusters.length < 2"
      class="truncate text-sm font-semibold"
    >{{ cluster ?? '—' }}</span>

    <select
      v-else
      class="rounded-md border border-border-subtle bg-surface px-2 py-1 text-sm font-semibold"
      aria-label="Cluster"
      :value="cluster ?? ''"
      @change="select(($event.target as HTMLSelectElement).value)"
    >
      <option
        v-for="item in clusters"
        :key="item.name"
        :value="item.name"
      >
        {{ item.name }}
      </option>
    </select>

    <span
      v-if="entry"
      class="hidden truncate text-xs text-muted sm:inline"
    >Reported {{ formatTimestamp(entry.generated_at) }}</span>
  </div>
</template>
