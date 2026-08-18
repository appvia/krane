<script setup lang="ts">
import type { SentencePart } from '@/features/tree/sentence'

defineProps<{
  details: {
    text: string
    branch: string
    tags: string
    path: string[]
    sentence: SentencePart[]
    children: number
    hidden: number
    chunk: string | null | undefined
  } | null
}>()
</script>

<template>
  <aside
    class="shrink-0 overflow-auto border-border-subtle bg-surface p-5 lg:w-80 lg:border-l"
    aria-label="Selected node"
  >
    <p
      v-if="!details"
      class="text-sm text-muted"
    >
      Select a node to see what it is.
    </p>

    <template v-else>
      <p class="text-xs font-semibold uppercase tracking-wide text-muted">
        {{ details.branch || 'Node' }}
      </p>
      <h2 class="mt-1 break-words text-base font-semibold">
        {{ details.text }}
      </h2>

      <!--
        The path read back as a sentence. Each level of the tree carries the word
        that joins it to the next, so a leaf states who is granted what.
      -->
      <p
        v-if="details.sentence.length"
        class="mt-4 rounded-md bg-surface-2 p-3 text-sm leading-relaxed"
      >
        <span
          v-for="(part, index) in details.sentence"
          :key="index"
          :class="part.subject ? 'font-semibold' : 'text-muted'"
          class="break-words"
        >{{ index > 0 ? ' ' : '' }}{{ part.text }}</span>
      </p>

      <dl class="mt-5 space-y-3 text-sm">
        <div v-if="details.tags">
          <dt class="text-muted">
            Tags
          </dt>
          <dd class="mt-1">
            {{ details.tags }}
          </dd>
        </div>
        <div v-if="details.children">
          <dt class="text-muted">
            Children
          </dt>
          <dd class="mt-1 tabular-nums">
            {{ details.children.toLocaleString() }}
          </dd>
        </div>
        <div v-if="details.chunk && details.hidden">
          <dt class="text-muted">
            Not loaded yet
          </dt>
          <dd class="mt-1 tabular-nums">
            {{ details.hidden.toLocaleString() }} nodes
          </dd>
        </div>
      </dl>
    </template>
  </aside>
</template>
