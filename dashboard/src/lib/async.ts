// Every view goes through the same four states, so a missing or half-written
// report shows an explanation and a retry instead of a blank page.

import { onScopeDispose, ref, shallowRef, watch, type WatchSource } from 'vue'

import { AppError, toAppError } from '@/lib/api'

export type AsyncState = 'loading' | 'error' | 'empty' | 'ready'

export type UseAsyncDataOptions<T> = {
  /** Loaded, but there is nothing to show — a state of its own, not an error. */
  isEmpty?: (data: T) => boolean
  /** Reload when any of these change (the selected cluster, a route param). */
  watch?: WatchSource[]
}

export function useAsyncData<T>(
  loader: (signal: AbortSignal) => Promise<T>,
  options: UseAsyncDataOptions<T> = {},
) {
  const state = ref<AsyncState>('loading')
  const data = shallowRef<T | null>(null)
  const error = shallowRef<AppError | null>(null)

  let controller: AbortController | null = null
  let latest = 0

  async function load() {
    controller?.abort()
    controller = new AbortController()

    const run = ++latest
    const { signal } = controller
    state.value = 'loading'
    error.value = null

    try {
      const result = await loader(signal)
      // A superseded run must not overwrite the current one: fetch rejects on
      // abort, but a loader doing its own work may resolve anyway.
      if (run !== latest) return
      data.value = result
      state.value = options.isEmpty?.(result) ? 'empty' : 'ready'
    } catch (cause) {
      if (run !== latest || signal.aborted) return
      data.value = null
      error.value = toAppError(cause)
      state.value = 'error'
    }
  }

  void load()

  if (options.watch?.length) {
    watch(options.watch, () => void load())
  }

  onScopeDispose(() => controller?.abort())

  return { state, data, error, retry: load }
}
