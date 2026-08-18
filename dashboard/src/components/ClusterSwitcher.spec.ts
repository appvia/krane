import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createRouter, createWebHashHistory } from 'vue-router'

import ClusterSwitcher from '@/components/ClusterSwitcher.vue'
import { resetClusters } from '@/lib/cluster'

function stubManifest(clusters: { name: string; generated_at: string }[], fallback = 'default') {
  vi.stubGlobal(
    'fetch',
    vi.fn(() => Promise.resolve(new Response(JSON.stringify({ default: fallback, clusters })))),
  )
}

async function mountSwitcher() {
  const router = createRouter({
    history: createWebHashHistory(),
    routes: [{ path: '/', name: 'overview', component: { template: '<div />' } }],
  })
  await router.push('/')
  await router.isReady()

  const wrapper = mount(ClusterSwitcher, { global: { plugins: [router] } })
  return { wrapper, router }
}

// The manifest is cached for the lifetime of the page, so each test needs its own.
beforeEach(() => resetClusters())

afterEach(() => vi.unstubAllGlobals())

describe('ClusterSwitcher', () => {
  it('shows the report time and no dropdown for a single cluster', async () => {
    stubManifest([{ name: 'default', generated_at: '2026-08-18T09:26:04Z' }])
    const { wrapper } = await mountSwitcher()

    await vi.waitFor(() => expect(wrapper.text()).toContain('default'))
    expect(wrapper.find('select').exists()).toBe(false)
    expect(wrapper.text()).toContain('Reported')
  })

  it('puts the chosen cluster in the query, so every view reloads for it', async () => {
    stubManifest(
      [
        { name: 'production', generated_at: '2026-08-18T08:00:00Z' },
        { name: 'staging', generated_at: '2026-08-18T09:00:00Z' },
      ],
      'staging',
    )
    const { wrapper, router } = await mountSwitcher()

    await vi.waitFor(() => expect(wrapper.find('select').exists()).toBe(true))
    const select = wrapper.get('select')
    expect((select.element as HTMLSelectElement).value).toBe('staging')

    await select.setValue('production')
    await vi.waitFor(() => expect(router.currentRoute.value.query.cluster).toBe('production'))
  })
})
