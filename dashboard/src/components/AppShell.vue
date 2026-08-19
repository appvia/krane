<script setup lang="ts">
import { PanelLeftClose, PanelLeftOpen, ShieldCheck } from 'lucide-vue-next'
import { ref, watch } from 'vue'

import SideNav from '@/components/SideNav.vue'
import ThemeToggle from '@/components/ThemeToggle.vue'
import { readSetting, writeSetting } from '@/lib/storage'

const STORAGE_KEY = 'krane.sidebar.collapsed'

const collapsed = ref(readSetting(STORAGE_KEY) === 'true')

watch(collapsed, (value) => writeSetting(STORAGE_KEY, String(value)))
</script>

<template>
  <div class="flex h-full">
    <aside
      class="flex shrink-0 flex-col border-r border-border-subtle bg-surface transition-[width]"
      :class="collapsed ? 'w-16' : 'w-60'"
    >
      <div class="flex h-14 items-center gap-2 border-b border-border-subtle px-4">
        <ShieldCheck
          :size="22"
          class="shrink-0 text-accent"
          aria-hidden="true"
        />
        <span
          v-if="!collapsed"
          class="text-base font-semibold tracking-tight"
        >Krane</span>
      </div>

      <SideNav :collapsed="collapsed" />

      <button
        type="button"
        class="mt-auto flex items-center gap-3 border-t border-border-subtle px-5 py-3 text-sm text-muted transition hover:text-content"
        :aria-label="collapsed ? 'Expand sidebar' : 'Collapse sidebar'"
        @click="collapsed = !collapsed"
      >
        <component
          :is="collapsed ? PanelLeftOpen : PanelLeftClose"
          :size="18"
          aria-hidden="true"
        />
        <span v-if="!collapsed">Collapse</span>
      </button>
    </aside>

    <div class="flex min-w-0 flex-1 flex-col">
      <header
        class="flex h-14 shrink-0 items-center gap-4 border-b border-border-subtle bg-surface px-6"
      >
        <slot name="topbar" />
        <div class="ml-auto flex items-center gap-2">
          <ThemeToggle />
        </div>
      </header>

      <!-- Views own their own scrolling: the tree and graph are full height panels. -->
      <main class="min-h-0 flex-1 overflow-hidden">
        <slot />
      </main>
    </div>
  </div>
</template>
