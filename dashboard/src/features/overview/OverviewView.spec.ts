import { mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { createRouter, createWebHashHistory } from 'vue-router'

import OverviewView from '@/features/overview/OverviewView.vue'

const CLUSTERS = { default: 'default', clusters: [{ name: 'default', generated_at: '2026-08-18T09:26:04Z' }] }

const REPORT = {
  results: [
    { id: 'a', status: 'danger', group_title: 'a', info: '', items: ['one'] },
    { id: 'b', status: 'info', group_title: 'b', info: '', items: ['two'] },
    { id: 'c', status: 'info', group_title: 'c', info: '', items: ['three'] },
    { id: 'd', status: 'success', group_title: 'd', info: '', items: null },
  ],
}

async function mountView() {
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) =>
      Promise.resolve(new Response(JSON.stringify(url.endsWith('clusters.json') ? CLUSTERS : REPORT))),
    ),
  )

  const router = createRouter({
    history: createWebHashHistory(),
    routes: [
      { path: '/', name: 'overview', component: OverviewView },
      { path: '/findings/:severity', name: 'findings', component: { template: '<div />' } },
      { path: '/tree', name: 'tree', component: { template: '<div />' } },
      { path: '/network', name: 'network', component: { template: '<div />' } },
    ],
  })
  await router.push('/')
  await router.isReady()

  const wrapper = mount(OverviewView, { global: { plugins: [router] } })
  await vi.waitFor(() => expect(wrapper.text()).not.toContain('Loading report'))
  return wrapper
}

afterEach(() => vi.unstubAllGlobals())

describe('OverviewView', () => {
  it('summarises the report by severity and links each tile to its findings', async () => {
    const wrapper = await mountView()

    const tiles = wrapper.findAll('a[href*="/findings/"]')
    expect(tiles.map((tile) => tile.text().replace(/\s+/g, ''))).toEqual([
      'Critical1',
      'Warning0',
      'Info2',
      'Passed1',
    ])
  })

  it('draws one donut segment per non-empty severity', async () => {
    const wrapper = await mountView()

    // Three severities have findings; the fourth must not leave a zero length dash.
    expect(wrapper.findAll('circle[stroke-dasharray]')).toHaveLength(3)
    expect(wrapper.find('figure').text()).toContain('4')
  })

  it('shows which cluster and report the numbers came from', async () => {
    const wrapper = await mountView()

    expect(wrapper.text()).toContain('default cluster')
    expect(wrapper.text()).toMatch(/reported \w/)
  })
})
