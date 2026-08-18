import { describe, expect, it } from 'vitest'

import { resolveCluster } from '@/lib/cluster'
import type { ClustersManifest } from '@/lib/types'

const manifest: ClustersManifest = {
  default: 'staging',
  clusters: [
    { name: 'production', generated_at: '2026-08-18T09:00:00Z' },
    { name: 'staging', generated_at: '2026-08-18T09:26:04Z' },
  ],
}

describe('resolveCluster', () => {
  it('honours a requested cluster that the manifest knows about', () => {
    expect(resolveCluster(manifest, 'production')).toBe('production')
  })

  it('falls back to the published default when nothing was requested', () => {
    expect(resolveCluster(manifest, null)).toBe('staging')
  })

  it('ignores a requested cluster that is not in the manifest', () => {
    // ?cluster= is user input that ends up in a fetch path.
    expect(resolveCluster(manifest, '../../../etc')).toBe('staging')
    expect(resolveCluster(manifest, 'does-not-exist')).toBe('staging')
  })

  it('falls back to the first cluster when the default is stale', () => {
    expect(resolveCluster({ default: 'removed', clusters: manifest.clusters }, null)).toBe('production')
  })

  it('resolves to nothing when no report has been published', () => {
    expect(resolveCluster({ default: '', clusters: [] }, 'production')).toBeNull()
  })
})
