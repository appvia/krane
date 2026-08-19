// The rules file is the user's own configuration, published verbatim by Ruby.
// It is parsed for the cards and also shown raw, because a rule's query and
// writer expressions are the point of the page.

import { parse } from 'yaml'

import { AppError, dataUrl, fetchText } from '@/lib/api'
import { useAsyncData } from '@/lib/async'
import { isSeverity, type Rule } from '@/lib/types'

export type RulesDocument = {
  raw: string
  rules: Rule[]
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : ''
}

/** YAML symbols come through as `:danger`. */
function severity(value: unknown) {
  const name = text(value).replace(/^:/, '')
  return isSeverity(name) ? name : null
}

export function parseRules(raw: string): RulesDocument {
  let document: unknown
  try {
    document = parse(raw)
  } catch (cause) {
    throw new AppError('malformed', cause instanceof Error ? cause.message : 'rules.yaml is not valid YAML')
  }

  const entries = (document as { rules?: unknown } | null)?.rules
  const rules = (Array.isArray(entries) ? entries : [])
    .filter((entry): entry is Record<string, unknown> => typeof entry === 'object' && entry !== null)
    .map((entry) => ({
      id: text(entry.id),
      group_title: text(entry.group_title),
      severity: severity(entry.severity),
      info: text(entry.info),
      template: text(entry.template) || null,
      query: text(entry.query) || null,
      disabled: entry.disabled === true,
    }))
    .filter((rule) => rule.id !== '')

  return { raw, rules }
}

/** Case insensitive search across everything a rule is identified by. */
export function matchRules(rules: readonly Rule[], query: string): Rule[] {
  const needle = query.trim().toLowerCase()
  if (needle === '') return [...rules]

  return rules.filter((rule) =>
    [rule.id, rule.group_title, rule.info, rule.template ?? '', rule.query ?? '']
      .join('\n')
      .toLowerCase()
      .includes(needle),
  )
}

export function useRules() {
  return useAsyncData<RulesDocument>(
    async (signal) => parseRules(await fetchText(dataUrl('config', 'rules.yaml'), signal)),
    { isEmpty: (document) => document.rules.length === 0 },
  )
}
