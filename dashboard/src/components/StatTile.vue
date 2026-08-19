<script setup lang="ts">
import { ArrowRight } from 'lucide-vue-next'
import { computed } from 'vue'

import { SEVERITY_STYLES } from '@/lib/severity'
import { SEVERITY_LABELS, type Severity } from '@/lib/types'

const props = defineProps<{ severity: Severity; count: number }>()

const style = computed(() => SEVERITY_STYLES[props.severity])
</script>

<template>
  <RouterLink
    :to="{ name: 'findings', params: { severity } }"
    class="group flex items-center gap-4 rounded-lg border border-border-subtle border-l-4 bg-surface p-4 transition hover:border-border-subtle hover:bg-surface-2"
    :class="style.edge"
  >
    <component
      :is="style.icon"
      :size="22"
      :class="style.text"
      aria-hidden="true"
    />
    <div class="min-w-0">
      <p class="text-xs font-semibold uppercase tracking-wide text-muted">
        {{ SEVERITY_LABELS[severity] }}
      </p>
      <p class="text-2xl font-semibold tabular-nums">
        {{ count }}
      </p>
    </div>
    <ArrowRight
      :size="16"
      class="ml-auto shrink-0 text-muted opacity-0 transition group-hover:opacity-100"
      aria-hidden="true"
    />
  </RouterLink>
</template>
