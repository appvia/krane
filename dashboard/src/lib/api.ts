// Data is fetched as plain static files from the same docroot the app is served
// from. There is no API: `krane report` writes the files, the server just serves
// them.

export type ErrorKind = 'missing' | 'http' | 'network' | 'malformed'

export class AppError extends Error {
  readonly kind: ErrorKind
  readonly status: number | null

  constructor(kind: ErrorKind, message: string, status: number | null = null) {
    super(message)
    this.name = 'AppError'
    this.kind = kind
    this.status = status
  }
}

/** Turns whatever a failed load threw into something a view can render. */
export function toAppError(cause: unknown): AppError {
  if (cause instanceof AppError) return cause
  return new AppError('network', cause instanceof Error ? cause.message : String(cause))
}

/**
 * Builds a URL for a file under data/. Relative to the document so the report
 * also opens straight off the filesystem, and every segment is encoded so a
 * cluster name can never climb out of the directory.
 */
export function dataUrl(...segments: string[]): string {
  const path = segments.map((segment) => encodeURIComponent(segment)).join('/')
  return new URL(`data/${path}`, document.baseURI).toString()
}

export async function fetchJson<T>(url: string, signal?: AbortSignal): Promise<T> {
  let response: Response
  try {
    response = await fetch(url, signal ? { signal } : {})
  } catch (cause) {
    if (cause instanceof DOMException && cause.name === 'AbortError') throw cause
    throw new AppError('network', `Could not reach ${url}`)
  }

  if (response.status === 404) {
    throw new AppError('missing', `${url} does not exist`, 404)
  }
  if (!response.ok) {
    throw new AppError('http', `${url} returned ${response.status}`, response.status)
  }

  try {
    return (await response.json()) as T
  } catch {
    // A half-written file should read as broken data, not as a network problem:
    // the report may simply be mid-regeneration.
    throw new AppError('malformed', `${url} is not valid JSON`, response.status)
  }
}
