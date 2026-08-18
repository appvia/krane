import { describe, expect, it } from 'vitest'

import { SEVERITIES, isSeverity } from './types'

describe('isSeverity', () => {
  it('accepts every severity the report emits', () => {
    for (const severity of SEVERITIES) expect(isSeverity(severity)).toBe(true)
  })

  // The severity arrives as a route param, so it is user supplied and reaches a
  // fetch URL and a token lookup.
  it('rejects anything else', () => {
    for (const value of ['', 'DANGER', '../config', undefined, null, 0, {}]) {
      expect(isSeverity(value)).toBe(false)
    }
  })
})
