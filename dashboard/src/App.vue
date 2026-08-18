<script setup lang="ts">
import AppShell from '@/components/AppShell.vue'
import ClusterSwitcher from '@/components/ClusterSwitcher.vue'
</script>

<template>
  <AppShell>
    <template #topbar>
      <ClusterSwitcher />
    </template>
    <RouterView />
  </AppShell>
</template>
