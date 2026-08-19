<script setup lang="ts">
import { computed } from 'vue'

import { SEVERITY_STYLES } from '@/lib/severity'
import { SEVERITY_LABELS, type Severity } from '@/lib/types'

const props = defineProps<{ severity: Severity; count?: number }>()

const style = computed(() => SEVERITY_STYLES[props.severity])
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-semibold"
    :class="style.badge"
  >
    <component
      :is="style.icon"
      :size="13"
      aria-hidden="true"
    />
    {{ SEVERITY_LABELS[severity] }}
    <template v-if="count !== undefined">· {{ count }}</template>
  </span>
</template>
