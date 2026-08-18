import { describe, expect, it } from 'vitest'

import { tally } from '@/lib/report'
import type { Finding } from '@/lib/types'

function finding(status: Finding['status'], id: string): Finding {
  return { id, status, group_title: id, info: '', items: null }
}

describe('tally', () => {
  it('counts findings by severity', () => {
    const counts = tally([finding('danger', 'a'), finding('info', 'b'), finding('info', 'c')])
    expect(counts).toEqual({ danger: 1, warning: 0, info: 2, success: 0 })
  })

  it('reports every severity as zero for an empty report', () => {
    expect(tally([])).toEqual({ danger: 0, warning: 0, info: 0, success: 0 })
  })
})
