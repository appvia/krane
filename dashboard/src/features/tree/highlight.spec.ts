import { describe, expect, it } from 'vitest'

import { highlight } from '@/features/tree/highlight'

describe('highlight', () => {
  it('returns the text untouched without a query', () => {
    expect(highlight('kube-system', '  ')).toEqual([{ text: 'kube-system', hit: false }])
  })

  it('splits around every match, case insensitively', () => {
    expect(highlight('kube-System kube', 'KUBE')).toEqual([
      { text: 'kube', hit: true },
      { text: '-System ', hit: false },
      { text: 'kube', hit: true },
    ])
  })

  it('keeps the original casing of the matched text', () => {
    expect(highlight('ServiceAccount', 'account')).toEqual([
      { text: 'Service', hit: false },
      { text: 'Account', hit: true },
    ])
  })

  it('reports no match as a single part', () => {
    expect(highlight('kube-system', 'zzz')).toEqual([{ text: 'kube-system', hit: false }])
  })

  it('does not loop forever on a repeated match', () => {
    expect(highlight('aaaa', 'aa')).toEqual([
      { text: 'aa', hit: true },
      { text: 'aa', hit: true },
    ])
  })
})
