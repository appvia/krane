<script setup lang="ts">
import { useVirtualizer } from '@tanstack/vue-virtual'
import { ChevronDown, ChevronUp, FoldVertical, Search } from 'lucide-vue-next'
import { computed, ref, watch } from 'vue'

import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import TreeDetails from '@/features/tree/TreeDetails.vue'
import TreeRow from '@/features/tree/TreeRow.vue'
import { useTree, type TreeLoader } from '@/features/tree/useTree'

// The loader is injectable so tests can flatten in process instead of spinning
// up a worker.
const props = defineProps<{ loader?: TreeLoader }>()

const ROW_HEIGHT = 32

const tree = useTree(props.loader)

const scroller = ref<HTMLElement | null>(null)

const virtualizer = useVirtualizer(
  computed(() => ({
    count: tree.rows.value.length,
    getScrollElement: () => scroller.value,
    estimateSize: () => ROW_HEIGHT,
    overscan: 12,
  })),
)

const items = computed(() =>
  virtualizer.value
    .getVirtualItems()
    .map((item) => ({ item, row: tree.rows.value[item.index] }))
    .filter((entry): entry is { item: (typeof entry)['item']; row: NonNullable<(typeof entry)['row']> } => entry.row !== undefined),
)

const matched = computed(() => new Set(tree.matches.value.ids))

// Walking matches is pointless if the row stays off screen.
watch(tree.current, (id) => {
  if (id === null) return
  const index = tree.rows.value.findIndex((row) => row.id === id)
  if (index !== -1) virtualizer.value.scrollToIndex(index, { align: 'center' })
})
</script>

<template>
  <section class="flex h-full flex-col">
    <header class="shrink-0 border-b border-border-subtle p-6 pb-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 class="text-xl font-semibold tracking-tight">
            RBAC tree
          </h1>
          <p class="mt-1 text-sm text-muted">
            Namespaces, actors, roles and resource access. Only roles in use are shown.
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-2">
          <label class="relative">
            <Search
              :size="15"
              class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted"
              aria-hidden="true"
            />
            <input
              v-model="tree.query.value"
              type="search"
              placeholder="Search the tree"
              aria-label="Search the tree"
              class="w-56 rounded-md border border-border-subtle bg-surface py-1.5 pl-9 pr-3 text-sm placeholder:text-muted"
            >
          </label>

          <div
            v-if="tree.query.value"
            class="flex items-center gap-1 text-sm text-muted"
          >
            <span class="tabular-nums">
              {{ tree.matches.value.total === 0 ? 0 : tree.position.value + 1 }} of
              {{ tree.matches.value.total.toLocaleString() }}
            </span>
            <button
              type="button"
              class="rounded border border-border-subtle p-1 transition hover:bg-surface-2"
              aria-label="Previous match"
              @click="tree.previous()"
            >
              <ChevronUp
                :size="14"
                aria-hidden="true"
              />
            </button>
            <button
              type="button"
              class="rounded border border-border-subtle p-1 transition hover:bg-surface-2"
              aria-label="Next match"
              @click="tree.next()"
            >
              <ChevronDown
                :size="14"
                aria-hidden="true"
              />
            </button>
          </div>

          <button
            type="button"
            class="flex items-center gap-2 rounded-md border border-border-subtle px-3 py-1.5 text-sm font-medium transition hover:bg-surface-2"
            @click="tree.collapseAll()"
          >
            <FoldVertical
              :size="14"
              aria-hidden="true"
            />
            Collapse
          </button>
        </div>
      </div>

      <!-- Search only sees loaded branches, so say when there are more to open. -->
      <p
        v-if="tree.unsearched.value.length"
        class="mt-3 flex flex-wrap items-center gap-2 text-sm text-muted"
      >
        {{ tree.unsearched.value.length }} unopened
        {{ tree.unsearched.value.length === 1 ? 'branch' : 'branches' }} also contain matches.
        <button
          type="button"
          class="rounded-md border border-border-subtle px-2 py-1 text-xs font-medium text-content transition hover:bg-surface-2"
          @click="tree.searchEverywhere()"
        >
          Load and search them
        </button>
      </p>

      <p
        v-if="tree.chunkError.value"
        class="mt-3 text-sm text-danger"
      >
        {{ tree.chunkError.value.message }}
      </p>
    </header>

    <LoadingState
      v-if="tree.state.value === 'loading'"
      label="Loading the tree…"
    />

    <ErrorState
      v-else-if="tree.state.value === 'error'"
      :error="tree.error.value"
      :cluster="tree.cluster.value"
      @retry="tree.retry()"
    />

    <div
      v-else
      class="flex min-h-0 flex-1 flex-col lg:flex-row"
    >
      <div
        ref="scroller"
        class="min-h-0 flex-1 overflow-auto"
        role="tree"
        aria-label="RBAC tree"
      >
        <div
          class="relative w-full"
          :style="{ height: `${virtualizer.getTotalSize()}px` }"
        >
          <TreeRow
            v-for="{ item, row } in items"
            :key="String(item.key)"
            class="absolute left-0 top-0 w-full"
            :style="{ height: `${item.size}px`, transform: `translateY(${item.start}px)` }"
            :row="row"
            :query="tree.query.value"
            :selected="tree.selected.value === row.id"
            :matched="matched.has(row.id)"
            :current-match="tree.current.value === row.id"
            @toggle="tree.toggle"
            @select="tree.select"
          />
        </div>
      </div>

      <TreeDetails :details="tree.details.value" />
    </div>

    <footer class="shrink-0 border-t border-border-subtle px-6 py-2 text-xs text-muted">
      {{ tree.rows.value.length.toLocaleString() }} rows shown ·
      {{ tree.loadedNodes.value.toLocaleString() }} nodes loaded
    </footer>
  </section>
</template>
