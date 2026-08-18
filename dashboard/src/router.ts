import { createRouter, createWebHashHistory, type RouteRecordRaw } from 'vue-router'

import { SEVERITIES, isSeverity } from '@/lib/types'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'overview',
    component: () => import('@/features/overview/OverviewView.vue'),
  },
  {
    // One view for all four severities, replacing the four near-identical pages
    // the Jekyll site generated.
    path: '/findings/:severity',
    name: 'findings',
    component: () => import('@/features/findings/FindingsView.vue'),
    props: true,
    beforeEnter: (to) => (isSeverity(to.params.severity) ? true : { name: 'findings', params: { severity: SEVERITIES[0] } }),
  },
  { path: '/tree', name: 'tree', component: () => import('@/features/tree/TreeView.vue') },
  { path: '/network', name: 'network', component: () => import('@/features/network/NetworkView.vue') },
  { path: '/rules', name: 'rules', component: () => import('@/features/rules/RulesView.vue') },
  { path: '/:pathMatch(.*)*', redirect: { name: 'overview' } },
]

export const router = createRouter({
  // Hash history keeps compiled/ a dumb static docroot: no rewrite rules to
  // configure in the Ruby server, and a report opens straight off the filesystem.
  history: createWebHashHistory(),
  routes,
})

// The selected cluster is a query param, so it has to survive navigation.
router.beforeEach((to, from) => {
  const cluster = to.query.cluster ?? from.query.cluster
  if (cluster && !to.query.cluster) {
    return { ...to, query: { ...to.query, cluster } }
  }
  return true
})
