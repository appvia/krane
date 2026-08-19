<script setup lang="ts">
import { computed } from 'vue'

import SeverityBadge from '@/components/SeverityBadge.vue'
import { marked } from '@/features/findings/marked'
import { SEVERITY_STYLES } from '@/lib/severity'
import type { Finding } from '@/lib/types'

const props = defineProps<{ finding: Finding }>()

// Every string below comes from cluster RBAC. Interpolation only — a subject or
// resource can be named anything at all.
const items = computed(() => props.finding.items ?? [])
const style = computed(() => SEVERITY_STYLES[props.finding.status])
</script>

<template>
  <article
    class="rounded-lg border border-border-subtle border-l-4 bg-surface p-5"
    :class="style.edge"
  >
    <header class="flex flex-wrap items-start justify-between gap-3">
      <h2 class="text-base font-semibold">
        {{ finding.group_title }}
      </h2>
      <SeverityBadge
        :severity="finding.status"
        :count="items.length"
      />
    </header>

    <p class="mt-2 text-sm text-muted">
      {{ finding.info }}
    </p>

    <ul
      v-if="items.length"
      class="mt-4 space-y-1 border-t border-border-subtle pt-4 font-mono text-sm"
    >
      <li
        v-for="(item, index) in items"
        :key="`${finding.id}-${index}`"
        class="break-words text-muted"
      >
        <span
          v-for="(part, at) in marked(item)"
          :key="at"
          :class="part.name ? 'font-semibold text-content' : ''"
        >{{ part.text }}</span>
      </li>
    </ul>
  </article>
</template>
