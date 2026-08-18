<script setup lang="ts">
import { ArrowRight, ListTree, Network } from 'lucide-vue-next'
import { computed } from 'vue'

import DonutChart from '@/components/DonutChart.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import StatTile from '@/components/StatTile.vue'
import { formatTimestamp } from '@/lib/format'
import { useFindingsReport } from '@/lib/report'
import { SEVERITY_STYLES } from '@/lib/severity'
import { SEVERITIES, SEVERITY_LABELS } from '@/lib/types'

const { state, error, retry, counts, cluster, entry } = useFindingsReport()

const generatedAt = computed(() => formatTimestamp(entry.value?.generated_at))

const total = computed(() => SEVERITIES.reduce((sum, severity) => sum + counts.value[severity], 0))

const slices = computed(() =>
  SEVERITIES.map((severity) => ({
    key: severity,
    label: SEVERITY_LABELS[severity],
    value: counts.value[severity],
    stroke: SEVERITY_STYLES[severity].stroke,
    fill: SEVERITY_STYLES[severity].fill,
  })),
)

const explore = [
  {
    to: { name: 'tree' },
    icon: ListTree,
    title: 'RBAC tree',
    detail:
      'Inspect RBAC by namespace, actor, role or resource. Only roles in use — assigned to a subject — are shown.',
  },
  {
    to: { name: 'network' },
    icon: Network,
    title: 'RBAC graph',
    detail:
      'A simplified graph of namespaces, actors and the roles attached to them, highlighting orphaned nodes.',
  },
]
</script>

<template>
  <section class="h-full overflow-auto p-6">
    <header class="mb-6">
      <h1 class="text-xl font-semibold tracking-tight">
        Overview
      </h1>
      <p class="mt-1 text-sm text-muted">
        <template v-if="cluster">
          {{ cluster }} cluster
        </template>
        <template v-if="generatedAt">
          · reported {{ generatedAt }}
        </template>
      </p>
    </header>

    <LoadingState
      v-if="state === 'loading'"
      label="Loading report…"
    />

    <ErrorState
      v-else-if="state === 'error'"
      :error="error"
      :cluster="cluster"
      @retry="retry"
    />

    <EmptyState
      v-else-if="state === 'empty'"
      title="No risk rules were evaluated"
      detail="The report contains no findings at all, which usually means no RBAC was ingested."
    />

    <template v-else>
      <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatTile
          v-for="severity in SEVERITIES"
          :key="severity"
          :severity="severity"
          :count="counts[severity]"
        />
      </div>

      <div class="mt-6 grid gap-6 lg:grid-cols-3">
        <div class="rounded-lg border border-border-subtle bg-surface p-6 lg:col-span-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-muted">
            Explore further
          </h2>
          <p class="mt-3 text-sm text-muted">
            The tiles above count risk rules by severity. Open a severity for the affected subjects,
            roles and resources, along with mitigation notes.
          </p>
          <div class="mt-5 grid gap-4 sm:grid-cols-2">
            <RouterLink
              v-for="item in explore"
              :key="item.title"
              :to="item.to"
              class="group rounded-lg border border-border-subtle p-4 transition hover:bg-surface-2"
            >
              <span class="flex items-center gap-2 text-sm font-semibold">
                <component
                  :is="item.icon"
                  :size="18"
                  class="text-accent"
                  aria-hidden="true"
                />
                {{ item.title }}
                <ArrowRight
                  :size="14"
                  class="ml-auto text-muted opacity-0 transition group-hover:opacity-100"
                  aria-hidden="true"
                />
              </span>
              <span class="mt-2 block text-sm text-muted">{{ item.detail }}</span>
            </RouterLink>
          </div>
        </div>

        <div class="rounded-lg border border-border-subtle bg-surface p-6">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-muted">
            Security checks
          </h2>
          <DonutChart
            class="mt-4"
            :slices="slices"
            :total="total"
            total-label="checks"
          />
        </div>
      </div>
    </template>
  </section>
</template>
