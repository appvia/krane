import { describe, expect, it } from 'vitest'

import { matchRules, parseRules } from '@/lib/rules'
import type { Rule } from '@/lib/types'

const YAML = `---
macros:
rules:
- id: subjects-with-open-cluster-wide-access
  group_title: Subjects with too open cluster-wide access
  severity: :danger
  info: |
    Subjects below have UNRESTRICTED cluster-wide access.
    Limit access to required namespaces only.
  template: unrestricted-cluster-wide-subjects

- id: example-rule
  group_title: Example rule
  severity: :info
  info: A rule with its own query
  query: |
    MATCH (s:Subject) RETURN s.name
  writer: 'res.map { |r| r }'
  disabled: true

- group_title: Nameless, and therefore not a rule
  severity: :warning
`

describe('parseRules', () => {
  it('reads the rules and keeps the file for the raw view', () => {
    const document = parseRules(YAML)

    expect(document.raw).toBe(YAML)
    expect(document.rules.map((rule) => rule.id)).toEqual([
      'subjects-with-open-cluster-wide-access',
      'example-rule',
    ])
  })

  it('turns the YAML symbol into a severity', () => {
    expect(parseRules(YAML).rules[0]?.severity).toBe('danger')
  })

  it('records how a rule finds its items', () => {
    const [templated, queried] = parseRules(YAML).rules

    expect(templated).toMatchObject({ template: 'unrestricted-cluster-wide-subjects', query: null })
    expect(queried?.query).toContain('MATCH (s:Subject)')
    expect(queried?.disabled).toBe(true)
  })

  it('defaults an unknown severity to none rather than guessing', () => {
    const rules = parseRules('rules:\n- id: odd\n  severity: :catastrophe\n').rules
    expect(rules[0]?.severity).toBeNull()
  })

  it('reports a broken file as malformed', () => {
    expect(() => parseRules('rules:\n- id: [unclosed\n')).toThrow(
      expect.objectContaining({ kind: 'malformed' }),
    )
  })

  it('survives a file with no rules at all', () => {
    expect(parseRules('macros:\n').rules).toEqual([])
    expect(parseRules('').rules).toEqual([])
  })
})

describe('matchRules', () => {
  const rules = parseRules(YAML).rules

  it('returns everything for an empty query', () => {
    expect(matchRules(rules, '   ')).toHaveLength(2)
  })

  it('matches on id, title, info and query, case insensitively', () => {
    expect(matchRules(rules, 'CLUSTER-WIDE').map((rule) => rule.id)).toEqual([
      'subjects-with-open-cluster-wide-access',
    ])
    expect(matchRules(rules, 'namespaces only')).toHaveLength(1)
    expect(matchRules(rules, 'match (s:subject)').map((rule) => rule.id)).toEqual(['example-rule'])
  })

  it('matches nothing when nothing matches', () => {
    expect(matchRules(rules, 'kubernetes')).toEqual([])
  })

  it('does not mutate the rules it was given', () => {
    const original: Rule[] = [...rules]
    matchRules(rules, 'example')
    expect(rules).toEqual(original)
  })
})
