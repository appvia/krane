<script setup lang="ts">
import { computed } from 'vue'

import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import FindingCard from '@/features/findings/FindingCard.vue'
import { useFindingsReport } from '@/lib/report'
import { SEVERITY_STYLES } from '@/lib/severity'
import { SEVERITIES, SEVERITY_LABELS, isSeverity } from '@/lib/types'

// The router redirects an unknown severity, so this is only a type narrowing.
const props = defineProps<{ severity: string }>()

const severity = computed(() => (isSeverity(props.severity) ? props.severity : SEVERITIES[0]))

const { state, data, error, retry, counts, cluster } = useFindingsReport()

const findings = computed(() => (data.value?.results ?? []).filter((item) => item.status === severity.value))
</script>

<template>
  <section class="h-full overflow-auto p-6">
    <header class="mb-6">
      <h1 class="text-xl font-semibold tracking-tight">
        Findings
      </h1>
      <p class="mt-1 text-sm text-muted">
        Every risk rule that matched, grouped by severity.
      </p>

      <nav
        class="mt-4 flex flex-wrap gap-2"
        aria-label="Severity"
      >
        <RouterLink
          v-for="option in SEVERITIES"
          :key="option"
          :to="{ name: 'findings', params: { severity: option } }"
          class="flex items-center gap-2 rounded-full border border-border-subtle px-3 py-1.5 text-sm font-medium text-muted transition hover:bg-surface-2 hover:text-content"
          active-class="border-transparent bg-surface-2 text-content"
        >
          <component
            :is="SEVERITY_STYLES[option].icon"
            :size="14"
            :class="SEVERITY_STYLES[option].text"
            aria-hidden="true"
          />
          {{ SEVERITY_LABELS[option] }}
          <span class="tabular-nums text-muted">{{ counts[option] }}</span>
        </RouterLink>
      </nav>
    </header>

    <LoadingState
      v-if="state === 'loading'"
      label="Loading findings…"
    />

    <ErrorState
      v-else-if="state === 'error'"
      :error="error"
      :cluster="cluster"
      @retry="retry"
    />

    <EmptyState
      v-else-if="!findings.length"
      :title="`No ${SEVERITY_LABELS[severity].toLowerCase()} findings`"
      detail="Nothing matched this severity in the latest report."
    />

    <div
      v-else
      class="space-y-4"
    >
      <FindingCard
        v-for="finding in findings"
        :key="finding.id"
        :finding="finding"
      />
    </div>
  </section>
</template>
