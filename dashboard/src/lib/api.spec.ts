import { afterEach, describe, expect, it, vi } from 'vitest'

import { AppError, dataUrl, fetchJson, toAppError } from '@/lib/api'

function respond(body: string, init: ResponseInit = {}) {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(body, init)))
}

afterEach(() => vi.unstubAllGlobals())

describe('dataUrl', () => {
  it('builds a document relative path under data/', () => {
    expect(dataUrl('default', 'rbac-findings.json')).toBe(
      new URL('data/default/rbac-findings.json', document.baseURI).toString(),
    )
  })

  it('encodes each segment so a cluster name cannot climb out', () => {
    const url = dataUrl('../../etc/passwd', 'rbac-findings.json')
    expect(url).toContain('data/..%2F..%2Fetc%2Fpasswd/rbac-findings.json')
    expect(new URL(url).pathname).not.toContain('/etc/passwd')
  })
})

describe('fetchJson', () => {
  it('returns the parsed body', async () => {
    respond('{"results":[]}')
    await expect(fetchJson<{ results: unknown[] }>('/data/x.json')).resolves.toEqual({ results: [] })
  })

  it('reports a 404 as missing, so the view can say "run the report"', async () => {
    respond('', { status: 404 })
    await expect(fetchJson('/data/x.json')).rejects.toMatchObject({ kind: 'missing', status: 404 })
  })

  it('reports other error statuses as http', async () => {
    respond('', { status: 500 })
    await expect(fetchJson('/data/x.json')).rejects.toMatchObject({ kind: 'http', status: 500 })
  })

  it('reports a half written file as malformed rather than as a network failure', async () => {
    respond('{"results":[')
    await expect(fetchJson('/data/x.json')).rejects.toMatchObject({ kind: 'malformed' })
  })

  it('reports an unreachable server as network', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))
    await expect(fetchJson('/data/x.json')).rejects.toMatchObject({ kind: 'network' })
  })

  it('lets an abort through untouched, so a superseded load stays silent', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockRejectedValue(new DOMException('The operation was aborted.', 'AbortError')),
    )
    await expect(fetchJson('/data/x.json')).rejects.toBeInstanceOf(DOMException)
  })
})

describe('toAppError', () => {
  it('passes an AppError through', () => {
    const error = new AppError('missing', 'gone')
    expect(toAppError(error)).toBe(error)
  })

  it('wraps anything else', () => {
    expect(toAppError(new Error('boom'))).toMatchObject({ kind: 'network', message: 'boom' })
  })
})
