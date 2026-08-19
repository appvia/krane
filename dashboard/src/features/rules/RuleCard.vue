<script setup lang="ts">
import { computed } from 'vue'

import SeverityBadge from '@/components/SeverityBadge.vue'
import { SEVERITY_STYLES } from '@/lib/severity'
import type { Rule } from '@/lib/types'

const props = defineProps<{ rule: Rule }>()

const edge = computed(() => (props.rule.severity ? SEVERITY_STYLES[props.rule.severity].edge : 'border-l-border-subtle'))
</script>

<template>
  <article
    class="rounded-lg border border-border-subtle border-l-4 bg-surface p-5"
    :class="edge"
  >
    <header class="flex flex-wrap items-start justify-between gap-3">
      <div class="min-w-0">
        <h2 class="text-base font-semibold">
          {{ rule.group_title || rule.id }}
        </h2>
        <p class="mt-0.5 font-mono text-xs text-muted">
          {{ rule.id }}
        </p>
      </div>
      <div class="flex shrink-0 items-center gap-2">
        <span
          v-if="rule.disabled"
          class="rounded-full bg-surface-2 px-2.5 py-0.5 text-xs font-semibold text-muted"
        >Disabled</span>
        <SeverityBadge
          v-if="rule.severity"
          :severity="rule.severity"
        />
      </div>
    </header>

    <p
      v-if="rule.info"
      class="mt-2 whitespace-pre-line text-sm text-muted"
    >
      {{ rule.info }}
    </p>

    <dl class="mt-4 border-t border-border-subtle pt-4 text-sm">
      <div
        v-if="rule.template"
        class="flex gap-2"
      >
        <dt class="text-muted">
          Template
        </dt>
        <dd class="font-mono">
          {{ rule.template }}
        </dd>
      </div>
      <div
        v-if="rule.query"
        class="mt-2"
      >
        <dt class="text-muted">
          Query
        </dt>
        <!-- Interpolated, so a query is shown as the text it is. -->
        <dd class="mt-1 overflow-x-auto rounded-md bg-surface-2 p-3 font-mono text-xs">
          <pre>{{ rule.query }}</pre>
        </dd>
      </div>
    </dl>
  </article>
</template>
