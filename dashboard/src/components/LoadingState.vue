<script setup lang="ts">
import { Loader2 } from 'lucide-vue-next'

const { label = 'Loading…' } = defineProps<{ label?: string }>()
</script>

<template>
  <div
    class="flex h-full min-h-40 flex-col items-center justify-center gap-3 text-muted"
    role="status"
  >
    <Loader2
      :size="24"
      class="animate-spin"
      aria-hidden="true"
    />
    <p class="text-sm">
      {{ label }}
    </p>
  </div>
</template>
