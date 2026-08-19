import { describe, expect, it } from 'vitest'

import { marked } from '@/features/findings/marked'

const read = (item: string) => marked(item).map((part) => (part.name ? `[${part.text}]` : part.text)).join('')

describe('marked', () => {
  it('picks the marked names out of the sentence', () => {
    expect(read('Group `system:bootstrappers` referenced by 4 roles')).toBe(
      'Group [system:bootstrappers] referenced by 4 roles',
    )
  })

  it('keeps the words around them as prose', () => {
    expect(marked('`kube-system` allows 10 subject(s)')).toEqual([
      { text: 'kube-system', name: true },
      { text: ' allows 10 subject(s)', name: false },
    ])
  })

  it('handles several names in one item', () => {
    expect(read('User `bob` is bound to non-existing ClusterRole `admin`')).toBe(
      'User [bob] is bound to non-existing ClusterRole [admin]',
    )
  })

  it('leaves an item from a rule that marks nothing exactly as it was', () => {
    // rules.yaml lets anyone write their own writer, and theirs still reads.
    expect(marked('some custom finding')).toEqual([{ text: 'some custom finding', name: false }])
  })

  it('leaves a stray backtick as the character it is', () => {
    expect(marked('a ` b')).toEqual([{ text: 'a ` b', name: false }])
  })

  it('survives an empty mark and an empty item', () => {
    expect(read('a `` b')).toBe('a [] b')
    expect(marked('')).toEqual([{ text: '', name: false }])
  })
})
