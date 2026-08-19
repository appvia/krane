// A donut is four dashes on one circle: each segment is a dash as long as its
// share of the circumference, offset by everything before it. No chart library.

export type DonutSlice = {
  key: string
  value: number
}

export type DonutSegment = {
  key: string
  value: number
  percent: number
  /** Dash length along the circle. */
  length: number
  /** stroke-dashoffset — negative, so the dash starts where the last one ended. */
  offset: number
}

export function donutSegments(slices: readonly DonutSlice[], circumference: number): DonutSegment[] {
  const drawable = slices.filter((slice) => slice.value > 0)
  const total = drawable.reduce((sum, slice) => sum + slice.value, 0)
  if (total === 0) return []

  let consumed = 0
  return drawable.map((slice) => {
    const length = (slice.value / total) * circumference
    const segment: DonutSegment = {
      key: slice.key,
      value: slice.value,
      percent: (slice.value / total) * 100,
      length,
      offset: -consumed,
    }
    consumed += length
    return segment
  })
}
