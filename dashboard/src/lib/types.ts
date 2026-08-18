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
