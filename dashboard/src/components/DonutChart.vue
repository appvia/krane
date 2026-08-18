<script setup lang="ts">
import { computed } from 'vue'

import { donutSegments } from '@/lib/donut'

const props = defineProps<{
  slices: { key: string; label: string; value: number; stroke: string; fill: string }[]
  total: number
  totalLabel: string
}>()

const RADIUS = 60
const THICKNESS = 16
const SIZE = (RADIUS + THICKNESS) * 2
const CIRCUMFERENCE = 2 * Math.PI * RADIUS

const segments = computed(() => donutSegments(props.slices, CIRCUMFERENCE))

const labels = computed(() => new Map(props.slices.map((slice) => [slice.key, slice.label])))
const strokes = computed(() => new Map(props.slices.map((slice) => [slice.key, slice.stroke])))
const fills = computed(() => new Map(props.slices.map((slice) => [slice.key, slice.fill])))
</script>

<template>
  <figure class="flex flex-col items-center gap-4">
    <div class="relative">
      <svg
        :width="SIZE"
        :height="SIZE"
        :viewBox="`0 0 ${SIZE} ${SIZE}`"
        role="img"
        :aria-label="`${total} ${totalLabel}`"
      >
        <!-- Rotated so the first segment starts at twelve o'clock. -->
        <g :transform="`rotate(-90 ${SIZE / 2} ${SIZE / 2})`">
          <circle
            :cx="SIZE / 2"
            :cy="SIZE / 2"
            :r="RADIUS"
            fill="none"
            :stroke-width="THICKNESS"
            class="stroke-surface-2"
          />
          <circle
            v-for="segment in segments"
            :key="segment.key"
            :cx="SIZE / 2"
            :cy="SIZE / 2"
            :r="RADIUS"
            fill="none"
            :stroke-width="THICKNESS"
            :stroke-dasharray="`${segment.length} ${CIRCUMFERENCE - segment.length}`"
            :stroke-dashoffset="segment.offset"
            :class="strokes.get(segment.key)"
          />
        </g>
      </svg>
      <div class="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
        <span class="text-2xl font-semibold tabular-nums">{{ total }}</span>
        <span class="text-xs text-muted">{{ totalLabel }}</span>
      </div>
    </div>

    <figcaption class="flex flex-wrap justify-center gap-x-4 gap-y-1 text-xs text-muted">
      <span
        v-for="segment in segments"
        :key="segment.key"
        class="inline-flex items-center gap-1.5"
      >
        <svg
          :width="8"
          :height="8"
          aria-hidden="true"
        >
          <circle
            cx="4"
            cy="4"
            r="4"
            :class="fills.get(segment.key)"
          />
        </svg>
        {{ labels.get(segment.key) }} {{ Math.round(segment.percent) }}%
      </span>
    </figcaption>
  </figure>
</template>
