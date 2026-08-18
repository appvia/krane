// Shapes of the static files Ruby publishes under compiled/data. Everything in
// here is derived from cluster RBAC, so treat every string as untrusted text.

export const SEVERITIES = ['danger', 'warning', 'info', 'success'] as const

export type Severity = (typeof SEVERITIES)[number]

export function isSeverity(value: unknown): value is Severity {
  return typeof value === 'string' && (SEVERITIES as readonly string[]).includes(value)
}

export const SEVERITY_LABELS: Record<Severity, string> = {
  danger: 'Critical',
  warning: 'Warning',
  info: 'Info',
  success: 'Passed',
}

/** One risk rule evaluated against the cluster. `items` is null when it passed. */
export type Finding = {
  id: string
  status: Severity
  group_title: string
  info: string
  items: string[] | null
}

export type SeverityCounts = Record<Severity, number>

/**
 * The published file also carries a `summary`, but it is derivable and counts
 * slightly differently (it skips findings with no items), so the dashboard
 * counts the findings it actually displays instead.
 */
export type FindingsReport = {
  results: Finding[]
}

export type ClusterEntry = {
  name: string
  generated_at: string
}

export type ClustersManifest = {
  default: string
  clusters: ClusterEntry[]
}
