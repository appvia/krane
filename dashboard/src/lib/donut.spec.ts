import { describe, expect, it } from 'vitest'

import { donutSegments } from '@/lib/donut'

const CIRCUMFERENCE = 100

describe('donutSegments', () => {
  it('splits the circumference in proportion to the values', () => {
    const segments = donutSegments(
      [
        { key: 'danger', value: 1 },
        { key: 'success', value: 3 },
      ],
      CIRCUMFERENCE,
    )

    expect(segments.map((s) => s.length)).toEqual([25, 75])
    expect(segments.map((s) => s.percent)).toEqual([25, 75])
  })

  it('offsets each segment by everything drawn before it', () => {
    const segments = donutSegments(
      [
        { key: 'a', value: 1 },
        { key: 'b', value: 1 },
        { key: 'c', value: 2 },
      ],
      CIRCUMFERENCE,
    )

    expect(segments.map((s) => s.offset)).toEqual([-0, -25, -50])
  })

  it('fills the whole circle', () => {
    const segments = donutSegments(
      [
        { key: 'a', value: 7 },
        { key: 'b', value: 11 },
        { key: 'c', value: 13 },
      ],
      CIRCUMFERENCE,
    )

    expect(segments.reduce((sum, s) => sum + s.length, 0)).toBeCloseTo(CIRCUMFERENCE)
  })

  it('drops empty slices so they leave no zero length dash behind', () => {
    const segments = donutSegments(
      [
        { key: 'danger', value: 0 },
        { key: 'success', value: 4 },
      ],
      CIRCUMFERENCE,
    )

    expect(segments).toHaveLength(1)
    expect(segments[0]).toMatchObject({ key: 'success', length: CIRCUMFERENCE })
  })

  it('draws nothing when there is nothing to draw', () => {
    expect(donutSegments([{ key: 'danger', value: 0 }], CIRCUMFERENCE)).toEqual([])
    expect(donutSegments([], CIRCUMFERENCE)).toEqual([])
  })
})
