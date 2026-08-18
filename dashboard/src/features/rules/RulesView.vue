<script setup lang="ts">
import { Search } from 'lucide-vue-next'
import { computed, ref } from 'vue'

import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import RuleCard from '@/features/rules/RuleCard.vue'
import { matchRules, useRules } from '@/lib/rules'

const { state, data, error, retry } = useRules()

const query = ref('')
const showSource = ref(false)

const rules = computed(() => data.value?.rules ?? [])
const matched = computed(() => matchRules(rules.value, query.value))
</script>

<template>
  <section class="flex h-full flex-col">
    <header class="shrink-0 border-b border-border-subtle p-6 pb-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 class="text-xl font-semibold tracking-tight">
            Risk rules
          </h1>
          <p class="mt-1 text-sm text-muted">
            The checks this report was evaluated against, from config/rules.yaml.
          </p>
        </div>

        <div class="flex items-center gap-2">
          <label class="relative">
            <Search
              :size="15"
              class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted"
              aria-hidden="true"
            />
            <input
              v-model="query"
              type="search"
              placeholder="Search rules"
              aria-label="Search rules"
              class="w-56 rounded-md border border-border-subtle bg-surface py-1.5 pl-9 pr-3 text-sm placeholder:text-muted"
            >
          </label>
          <button
            type="button"
            class="rounded-md border border-border-subtle px-3 py-1.5 text-sm font-medium transition hover:bg-surface-2"
            :aria-pressed="showSource"
            @click="showSource = !showSource"
          >
            {{ showSource ? 'Show rules' : 'Show YAML' }}
          </button>
        </div>
      </div>
    </header>

    <div class="min-h-0 flex-1 overflow-auto p-6">
      <LoadingState
        v-if="state === 'loading'"
        label="Loading rules…"
      />

      <ErrorState
        v-else-if="state === 'error'"
        :error="error"
        @retry="retry"
      />

      <EmptyState
        v-else-if="state === 'empty'"
        title="No rules are defined"
        detail="config/rules.yaml was published but contains no rules."
      />

      <!-- Interpolated into a text node: the file is shown, never executed. -->
      <pre
        v-else-if="showSource"
        class="overflow-x-auto rounded-lg border border-border-subtle bg-surface p-4 font-mono text-xs leading-relaxed"
      >{{ data?.raw }}</pre>

      <EmptyState
        v-else-if="!matched.length"
        title="No rules match"
        :detail="`Nothing in the ${rules.length} defined rules matches “${query}”.`"
      />

      <div
        v-else
        class="space-y-4"
      >
        <p class="text-sm text-muted">
          {{ matched.length }} of {{ rules.length }} rules
        </p>
        <RuleCard
          v-for="rule in matched"
          :key="rule.id"
          :rule="rule"
        />
      </div>
    </div>
  </section>
</template>
