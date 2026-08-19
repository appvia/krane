<script setup lang="ts">
import { AlertTriangle, LayoutDashboard, ListTree, Network, ScrollText } from 'lucide-vue-next'
import type { FunctionalComponent } from 'vue'

import type { RouteLocationRaw } from 'vue-router'

defineProps<{ collapsed: boolean }>()

type NavItem = { label: string; icon: FunctionalComponent; to: RouteLocationRaw }

const items: NavItem[] = [
  { label: 'Overview', icon: LayoutDashboard, to: { name: 'overview' } },
  { label: 'Findings', icon: AlertTriangle, to: { name: 'findings', params: { severity: 'danger' } } },
  { label: 'RBAC tree', icon: ListTree, to: { name: 'tree' } },
  { label: 'RBAC graph', icon: Network, to: { name: 'network' } },
  { label: 'Risk rules', icon: ScrollText, to: { name: 'rules' } },
]
</script>

<template>
  <nav
    class="flex flex-col gap-1 p-3"
    aria-label="Sections"
  >
    <RouterLink
      v-for="item in items"
      :key="item.label"
      :to="item.to"
      class="flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-muted transition hover:bg-surface-2 hover:text-content"
      active-class="bg-accent text-accent-fg hover:bg-accent hover:text-accent-fg"
      :title="collapsed ? item.label : undefined"
    >
      <component
        :is="item.icon"
        :size="18"
        class="shrink-0"
        aria-hidden="true"
      />
      <span
        v-if="!collapsed"
        class="truncate"
      >{{ item.label }}</span>
      <span
        v-else
        class="sr-only"
      >{{ item.label }}</span>
    </RouterLink>
  </nav>
</template>
