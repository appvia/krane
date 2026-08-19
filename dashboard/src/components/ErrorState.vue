<script setup lang="ts">
import { AlertCircle, RotateCw } from 'lucide-vue-next'
import { computed } from 'vue'

import type { AppError } from '@/lib/api'

const props = defineProps<{ error: AppError | null; cluster?: string | null }>()

defineEmits<{ retry: [] }>()

// A missing file is the ordinary case — the report has not been run — so it gets
// the instruction rather than an error dump.
const headline = computed(() => (props.error?.kind === 'missing' ? 'No report yet' : 'Could not load this view'))

const detail = computed(() => {
  if (props.error?.kind !== 'missing') return props.error?.message ?? 'Unknown error'
  return props.cluster
    ? `There is no report data for the ${props.cluster} cluster.`
    : 'There is no report data to show.'
})

const command = computed(() =>
  props.error?.kind === 'missing' ? `krane report -c ${props.cluster ?? 'CLUSTER'}` : null,
)
</script>

<template>
  <div class="flex h-full min-h-40 flex-col items-center justify-center gap-3 p-6 text-center">
    <AlertCircle
      :size="24"
      class="text-danger"
      aria-hidden="true"
    />
    <p class="text-sm font-medium">
      {{ headline }}
    </p>
    <p class="max-w-md text-sm text-muted">
      {{ detail }}
    </p>
    <code
      v-if="command"
      class="rounded-md bg-surface-2 px-3 py-1.5 font-mono text-xs"
    >{{ command }}</code>
    <button
      type="button"
      class="mt-1 flex items-center gap-2 rounded-md border border-border-subtle px-3 py-1.5 text-sm font-medium transition hover:bg-surface-2"
      @click="$emit('retry')"
    >
      <RotateCw
        :size="14"
        aria-hidden="true"
      />
      Retry
    </button>
  </div>
</template>
