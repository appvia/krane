import { mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { createRouter, createWebHashHistory } from 'vue-router'

import FindingsView from '@/features/findings/FindingsView.vue'

const CLUSTERS = { default: 'default', clusters: [{ name: 'default', generated_at: '2026-08-18T09:26:04Z' }] }

const REPORT = {
  summary: { danger: 1, success: 1 },
  results: [
    {
      id: 'open-access',
      status: 'danger',
      group_title: 'Subjects with too open cluster-wide access',
      info: 'Review these.',
      items: ['ServiceAccount default'],
    },
    { id: 'passed', status: 'success', group_title: 'Nothing risky here', info: '', items: null },
    // A status the frontend does not know about must not reach a card.
    { id: 'future', status: 'catastrophe', group_title: 'From a newer krane', info: '', items: ['x'] },
  ],
}

function stubData() {
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) => {
      const body = url.endsWith('clusters.json') ? CLUSTERS : REPORT
      return Promise.resolve(new Response(JSON.stringify(body)))
    }),
  )
}

async function mountView(severity: string) {
  const router = createRouter({
    history: createWebHashHistory(),
    routes: [{ path: '/findings/:severity', name: 'findings', component: FindingsView }],
  })
  await router.push({ name: 'findings', params: { severity } })
  await router.isReady()

  const wrapper = mount(FindingsView, {
    props: { severity },
    global: { plugins: [router] },
  })
  await vi.waitFor(() => expect(wrapper.text()).not.toContain('Loading findings'))
  return wrapper
}

afterEach(() => vi.unstubAllGlobals())

describe('FindingsView', () => {
  it('loads the report for the resolved cluster and lists the requested severity', async () => {
    stubData()
    const wrapper = await mountView('danger')

    const requested = vi.mocked(fetch).mock.calls.map(([url]) => String(url))
    expect(requested.some((url) => url.endsWith('data/clusters.json'))).toBe(true)
    expect(requested.some((url) => url.endsWith('data/default/rbac-findings.json'))).toBe(true)

    expect(wrapper.findAll('article')).toHaveLength(1)
    expect(wrapper.text()).toContain('Subjects with too open cluster-wide access')
    expect(wrapper.text()).not.toContain('Nothing risky here')
    expect(wrapper.text()).not.toContain('From a newer krane')
  })

  it('explains an empty severity instead of showing a blank page', async () => {
    stubData()
    const wrapper = await mountView('warning')

    expect(wrapper.findAll('article')).toHaveLength(0)
    expect(wrapper.text()).toContain('No warning findings')
  })

  it('offers a retry when the report cannot be loaded', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) =>
        Promise.resolve(
          url.endsWith('clusters.json')
            ? new Response(JSON.stringify(CLUSTERS))
            : new Response('', { status: 404 }),
        ),
      ),
    )

    const wrapper = await mountView('danger')

    expect(wrapper.text()).toContain('No report yet')
    expect(wrapper.text()).toContain('krane report -c default')
    expect(wrapper.find('button').text()).toContain('Retry')
  })
})
