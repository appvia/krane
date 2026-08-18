<script setup lang="ts">
import { ChevronDown, ChevronRight, Loader2 } from 'lucide-vue-next'
import { computed } from 'vue'

import { highlight } from '@/features/tree/highlight'
import type { TreeRow } from '@/features/tree/useTree'

const props = defineProps<{
  row: TreeRow
  query: string
  selected: boolean
  matched: boolean
  currentMatch: boolean
}>()

const emit = defineEmits<{ toggle: [number]; select: [number] }>()

const parts = computed(() => highlight(props.row.text, props.query))
const indent = computed(() => `${props.row.depth * 16 + 8}px`)
</script>

<template>
  <div
    class="flex h-8 items-center gap-1 pr-3 text-sm"
    :class="[
      selected ? 'bg-accent/10' : 'hover:bg-surface-2',
      currentMatch ? 'ring-1 ring-inset ring-accent' : '',
    ]"
    role="treeitem"
    :aria-level="row.depth + 1"
    :aria-expanded="row.expandable ? row.expanded : undefined"
    :aria-selected="selected"
  >
    <div
      class="flex shrink-0 items-center"
      :style="{ paddingLeft: indent }"
    >
      <button
        v-if="row.expandable"
        type="button"
        class="flex size-5 items-center justify-center rounded text-muted transition hover:bg-surface-2 hover:text-content"
        :aria-label="row.expanded ? `Collapse ${row.text}` : `Expand ${row.text}`"
        @click="emit('toggle', row.id)"
      >
        <Loader2
          v-if="row.loading"
          :size="14"
          class="animate-spin"
          aria-hidden="true"
        />
        <component
          :is="row.expanded ? ChevronDown : ChevronRight"
          v-else
          :size="14"
          aria-hidden="true"
        />
      </button>
      <span
        v-else
        class="size-5"
      />
    </div>

    <button
      type="button"
      class="min-w-0 flex-1 truncate text-left"
      :class="matched ? 'font-medium' : ''"
      @click="emit('select', row.id)"
    >
      <span
        v-for="(part, index) in parts"
        :key="index"
        :class="part.hit ? 'rounded bg-warning-bg px-0.5 text-warning-fg' : ''"
      >{{ part.text }}</span>
    </button>

    <span
      v-for="tag in row.tags"
      :key="tag"
      class="shrink-0 rounded-full bg-surface-2 px-2 py-0.5 text-xs text-muted"
    >{{ tag }}</span>

    <span
      v-if="row.hidden > 0 && !row.expanded"
      class="shrink-0 text-xs tabular-nums text-muted"
    >{{ row.hidden.toLocaleString() }}</span>
  </div>
</template>
