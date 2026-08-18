// Fetches and flattens tree chunks off the main thread: the parse of a large
// chunk is the one job that would otherwise freeze the UI, so the raw JSON never
// reaches the window at all.

import { flatten, transferables, type FlattenOptions } from '@/features/tree/flatten'
import type { RbacTreeNode } from '@/lib/types'

export type FlattenRequest = FlattenOptions & {
  id: number
  url: string
}

export type FlattenFailure = {
  id: number
  error: { kind: 'missing' | 'http' | 'network' | 'malformed'; message: string }
}

function fail(id: number, kind: FlattenFailure['error']['kind'], message: string) {
  self.postMessage({ id, error: { kind, message } } satisfies FlattenFailure)
}

self.onmessage = async (event: MessageEvent<FlattenRequest>) => {
  const { id, url, offset, parent, depth } = event.data

  let response: Response
  try {
    response = await fetch(url)
  } catch {
    fail(id, 'network', `Could not reach ${url}`)
    return
  }

  if (response.status === 404) {
    fail(id, 'missing', `${url} does not exist`)
    return
  }
  if (!response.ok) {
    fail(id, 'http', `${url} returned ${response.status}`)
    return
  }

  let document: RbacTreeNode
  try {
    document = await response.json()
  } catch {
    fail(id, 'malformed', `${url} is not valid JSON`)
    return
  }

  // The index is one root node; a chunk holds the children of an existing node,
  // which is exactly what having a parent to graft onto means.
  const roots = parent === -1 ? [document] : (document.nodes ?? [])
  const flat = flatten(roots, { offset, parent, depth })

  self.postMessage({ id, flat }, { transfer: transferables(flat) })
}
