<script setup lang="ts">
import { Inbox } from 'lucide-vue-next'

defineProps<{ title: string; detail?: string }>()
</script>

<template>
  <div class="flex h-full min-h-40 flex-col items-center justify-center gap-2 p-6 text-center">
    <Inbox
      :size="24"
      class="text-muted"
      aria-hidden="true"
    />
    <p class="text-sm font-medium">
      {{ title }}
    </p>
    <p
      v-if="detail"
      class="max-w-md text-sm text-muted"
    >
      {{ detail }}
    </p>
    <slot />
  </div>
</template>
