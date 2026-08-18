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

/**
 * A risk rule as written in config/rules.yaml. Severities are YAML symbols
 * there (`:danger`), and a rule finds its items either through a built-in
 * template or a custom graph query.
 */
export type Rule = {
  id: string
  group_title: string
  severity: Severity | null
  info: string
  template: string | null
  query: string | null
  disabled: boolean
}

/**
 * A node in the published RBAC tree. Per the data contract a node has `nodes`
 * (children inline), or `chunk` (children live in another file), or neither
 * (a leaf) — so a chunk may itself hold chunk references.
 */
export type RbacTreeNode = {
  text?: string
  branch?: string
  tags?: string[]
  nodes?: RbacTreeNode[]
  chunk?: string
  node_count?: number
  facet?: string
  resource_kind?: string
}

/** search.json: which chunks contain a given (lowercased) node text. */
export type TreeSearchIndex = {
  chunks: string[]
  terms: Record<string, number[]>
}
