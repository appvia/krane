// Tailwind only generates classes it can see in the source, so severity styling
// is a literal lookup rather than an interpolated class name.

import { AlertTriangle, CheckCircle2, Info, ShieldAlert } from 'lucide-vue-next'
import type { FunctionalComponent } from 'vue'

import type { Severity } from '@/lib/types'

export type SeverityStyle = {
  icon: FunctionalComponent
  /** Badge and pill backgrounds, paired fg/bg for contrast. */
  badge: string
  /** Solid colour, for icons and marks. */
  text: string
  /** Donut segment. */
  stroke: string
  /** Legend swatch — a separate literal because Tailwind cannot see a derived one. */
  fill: string
  /** Left edge of a card or tile. */
  edge: string
}

export const SEVERITY_STYLES: Record<Severity, SeverityStyle> = {
  danger: {
    icon: ShieldAlert,
    badge: 'bg-danger-bg text-danger-fg',
    text: 'text-danger',
    stroke: 'stroke-danger',
    fill: 'fill-danger',
    edge: 'border-l-danger',
  },
  warning: {
    icon: AlertTriangle,
    badge: 'bg-warning-bg text-warning-fg',
    text: 'text-warning',
    stroke: 'stroke-warning',
    fill: 'fill-warning',
    edge: 'border-l-warning',
  },
  info: {
    icon: Info,
    badge: 'bg-info-bg text-info-fg',
    text: 'text-info',
    stroke: 'stroke-info',
    fill: 'fill-info',
    edge: 'border-l-info',
  },
  success: {
    icon: CheckCircle2,
    badge: 'bg-success-bg text-success-fg',
    text: 'text-success',
    stroke: 'stroke-success',
    fill: 'fill-success',
    edge: 'border-l-success',
  },
}
