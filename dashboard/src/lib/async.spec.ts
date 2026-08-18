import { effectScope, ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { AppError } from '@/lib/api'
import { useAsyncData } from '@/lib/async'

/** useAsyncData registers onScopeDispose, so it needs an owning scope. */
function inScope<T>(fn: () => T): { result: T; stop: () => void } {
  const scope = effectScope()
  const result = scope.run(fn) as T
  return { result, stop: () => scope.stop() }
}

const settled = () => vi.waitFor(() => expect(true).toBe(true))

describe('useAsyncData', () => {
  it('starts loading and lands on ready', async () => {
    const { result } = inScope(() => useAsyncData(async () => 'data'))

    expect(result.state.value).toBe('loading')
    await vi.waitFor(() => expect(result.state.value).toBe('ready'))
    expect(result.data.value).toBe('data')
    expect(result.error.value).toBeNull()
  })

  it('treats "loaded but nothing to show" as its own state', async () => {
    const { result } = inScope(() =>
      useAsyncData(async () => [] as number[], { isEmpty: (rows) => rows.length === 0 }),
    )

    await vi.waitFor(() => expect(result.state.value).toBe('empty'))
    expect(result.data.value).toEqual([])
  })

  it('keeps the error for the view to render', async () => {
    const { result } = inScope(() =>
      useAsyncData(async () => {
        throw new AppError('missing', 'no report')
      }),
    )

    await vi.waitFor(() => expect(result.state.value).toBe('error'))
    expect(result.error.value).toMatchObject({ kind: 'missing', message: 'no report' })
    expect(result.data.value).toBeNull()
  })

  it('reloads on retry', async () => {
    let attempt = 0
    const { result } = inScope(() =>
      useAsyncData(async () => {
        attempt += 1
        if (attempt === 1) throw new AppError('network', 'down')
        return 'second'
      }),
    )

    await vi.waitFor(() => expect(result.state.value).toBe('error'))
    await result.retry()
    expect(result.state.value).toBe('ready')
    expect(result.data.value).toBe('second')
  })

  it('reloads when a watched source changes', async () => {
    const cluster = ref('a')
    const seen: string[] = []
    const { result } = inScope(() =>
      useAsyncData(
        async () => {
          seen.push(cluster.value)
          return cluster.value
        },
        { watch: [cluster] },
      ),
    )

    await vi.waitFor(() => expect(result.state.value).toBe('ready'))
    cluster.value = 'b'
    await vi.waitFor(() => expect(result.data.value).toBe('b'))
    expect(seen).toEqual(['a', 'b'])
  })

  it('ignores a superseded load that resolves late', async () => {
    const order = ref('slow')
    const { result } = inScope(() =>
      useAsyncData(
        async () => {
          const value = order.value
          if (value === 'slow') await new Promise((resolve) => setTimeout(resolve, 20))
          return value
        },
        { watch: [order] },
      ),
    )

    order.value = 'fast'
    await vi.waitFor(() => expect(result.data.value).toBe('fast'))
    await new Promise((resolve) => setTimeout(resolve, 40))
    expect(result.data.value).toBe('fast')
  })

  it('aborts the in flight request when the scope is torn down', async () => {
    const signals: AbortSignal[] = []
    const { stop } = inScope(() =>
      useAsyncData(async (signal) => {
        signals.push(signal)
        return new Promise<string>(() => undefined)
      }),
    )

    await settled()
    stop()
    expect(signals.at(0)?.aborted).toBe(true)
  })
})
