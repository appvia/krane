<script setup lang="ts">
import { Moon, Sun } from 'lucide-vue-next'
import { computed } from 'vue'

import { useTheme } from '@/lib/theme'

const { theme, toggle } = useTheme()

const label = computed(() => (theme.value === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'))
</script>

<template>
  <button
    type="button"
    class="rounded-md p-2 text-muted transition hover:bg-surface-2 hover:text-content"
    :aria-label="label"
    :title="label"
    @click="toggle"
  >
    <Sun
      v-if="theme === 'dark'"
      :size="18"
      aria-hidden="true"
    />
    <Moon
      v-else
      :size="18"
      aria-hidden="true"
    />
  </button>
</template>
