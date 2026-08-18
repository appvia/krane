import { mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'

import RulesView from '@/features/rules/RulesView.vue'

const YAML = `rules:
- id: subjects-with-open-cluster-wide-access
  group_title: Subjects with too open cluster-wide access
  severity: :danger
  info: Limit access to required namespaces only.
  template: unrestricted-cluster-wide-subjects
- id: bindings-without-subjects
  group_title: Bindings without any Subjects
  severity: :warning
  info: Should those bindings exist?
  template: bindings-without-subjects
`

async function mountView(body: string | Response = YAML) {
  vi.stubGlobal(
    'fetch',
    vi.fn(() => Promise.resolve(typeof body === 'string' ? new Response(body) : body)),
  )

  const wrapper = mount(RulesView)
  await vi.waitFor(() => expect(wrapper.text()).not.toContain('Loading rules'))
  return wrapper
}

afterEach(() => vi.unstubAllGlobals())

describe('RulesView', () => {
  it('lists the configured rules', async () => {
    const wrapper = await mountView()

    expect(wrapper.findAll('article')).toHaveLength(2)
    expect(wrapper.text()).toContain('2 of 2 rules')
    expect(vi.mocked(fetch).mock.calls.map(([url]) => String(url))[0]).toContain('data/config/rules.yaml')
  })

  it('filters as you search', async () => {
    const wrapper = await mountView()

    await wrapper.get('input[type="search"]').setValue('bindings')
    expect(wrapper.findAll('article')).toHaveLength(1)
    expect(wrapper.text()).toContain('1 of 2 rules')

    await wrapper.get('input[type="search"]').setValue('nothing here')
    expect(wrapper.text()).toContain('No rules match')
  })

  it('shows the file itself as text, not as markup', async () => {
    const hostile = `${YAML}# <img src=x onerror="alert(1)">\n`
    const wrapper = await mountView(hostile)

    await wrapper.get('button[aria-pressed]').trigger('click')

    const source = wrapper.get('pre')
    expect(source.text()).toContain('<img src=x onerror="alert(1)">')
    expect(wrapper.find('img').exists()).toBe(false)
  })

  it('explains a missing rules file', async () => {
    const wrapper = await mountView(new Response('', { status: 404 }))

    expect(wrapper.text()).toContain('No report yet')
    expect(wrapper.findAll('button').map((button) => button.text())).toContain('Retry')
  })
})
