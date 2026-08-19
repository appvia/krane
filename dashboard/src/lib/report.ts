// Overview and Findings read the same published file, so they share one loader.

import { computed } from 'vue'

import { dataUrl, fetchJson } from '@/lib/api'
import { useAsyncData } from '@/lib/async'
import { currentCluster, useCluster } from '@/lib/cluster'
import { SEVERITIES, isSeverity, type Finding, type FindingsReport, type SeverityCounts } from '@/lib/types'

function normalise(raw: unknown): FindingsReport {
  const source = (raw ?? {}) as Partial<FindingsReport>
  const results = Array.isArray(source.results) ? source.results : []
  return {
    // An unknown status would have no styling to look up, so drop it rather
    // than render a broken card.
    results: results.filter((finding): finding is Finding => isSeverity(finding?.status)),
  }
}

export function tally(results: readonly Finding[]): SeverityCounts {
  const counts = Object.fromEntries(SEVERITIES.map((severity) => [severity, 0])) as SeverityCounts
  for (const finding of results) counts[finding.status] += 1
  return counts
}

export function useFindingsReport() {
  const { cluster, entry, requested } = useCluster()

  const query = useAsyncData<FindingsReport>(
    async (signal) => {
      const name = await currentCluster(requested.value)
      return normalise(await fetchJson<unknown>(dataUrl(name, 'rbac-findings.json'), signal))
    },
    {
      isEmpty: (report) => report.results.length === 0,
      watch: [requested],
    },
  )

  const counts = computed(() => tally(query.data.value?.results ?? []))

  return { ...query, counts, cluster, entry }
}
