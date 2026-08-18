import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'

import FindingCard from '@/features/findings/FindingCard.vue'
import type { Finding } from '@/lib/types'

const HOSTILE = '<img src=x onerror="alert(1)">'

const finding: Finding = {
  id: 'subjects-with-open-cluster-wide-access',
  status: 'danger',
  group_title: `Subjects with too open access ${HOSTILE}`,
  info: `Review the items below ${HOSTILE}`,
  items: [`ServiceAccount ${HOSTILE}`, '<script>alert(2)</script>'],
}

describe('FindingCard', () => {
  // Every string in a finding is a cluster resource name, so it is attacker
  // controlled. This is the regression test for the old dashboard's habit of
  // building HTML strings from report data.
  it('renders hostile report data as text, never as markup', () => {
    const wrapper = mount(FindingCard, { props: { finding } })

    expect(wrapper.find('img').exists()).toBe(false)
    expect(wrapper.find('script').exists()).toBe(false)
    // The payload survives as text with its angle brackets escaped, which is
    // what makes it inert — the browser never parses it as an element.
    expect(wrapper.html()).toContain('&lt;img src=x onerror="alert(1)"&gt;')
    expect(wrapper.text()).toContain(HOSTILE)
    expect(wrapper.text()).toContain('<script>alert(2)</script>')
  })

  it('shows how many items the finding matched', () => {
    const wrapper = mount(FindingCard, { props: { finding } })

    expect(wrapper.findAll('li')).toHaveLength(2)
    expect(wrapper.text()).toContain('Critical · 2')
  })

  it('renders a passing finding with no items', () => {
    const wrapper = mount(FindingCard, {
      props: { finding: { ...finding, status: 'success', items: null } },
    })

    expect(wrapper.findAll('li')).toHaveLength(0)
    expect(wrapper.text()).toContain('Passed · 0')
  })
})
