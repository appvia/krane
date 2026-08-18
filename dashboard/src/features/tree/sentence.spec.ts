import { describe as group, expect, it } from 'vitest'

import { describe, type SentenceNode } from '@/features/tree/sentence'

// A real path from a docker-desktop report, from the namespace down to the role.
const PATH: SentenceNode[] = [
  { text: 'kube-system', tag: 'Namespace' },
  { text: 'Group', tag: 'admits' },
  { text: 'system:bootstrappers:kubeadm:default-node-token', tag: 'Group' },
  { text: 'resource', tag: 'to' },
  { text: '[certificates.k8s.io] certificatesigningrequests', tag: 'resource' },
  { text: 'create', tag: 'action' },
  { text: 'system:node-bootstrapper', tag: 'defined by ClusterRole' },
]

const read = (nodes: SentenceNode[]) => describe(nodes).map((part) => part.text).join(' ')

group('describe', () => {
  it('reads a path back as a sentence', () => {
    expect(read(PATH)).toBe(
      'Namespace kube-system admits Group system:bootstrappers:kubeadm:default-node-token ' +
        'to resource [certificates.k8s.io] certificatesigningrequests action create ' +
        'defined by ClusterRole system:node-bootstrapper',
    )
  })

  it('marks the names apart from the words joining them', () => {
    const named = describe(PATH).filter((part) => part.subject).map((part) => part.text)

    expect(named).toEqual([
      'kube-system',
      'system:bootstrappers:kubeadm:default-node-token',
      '[certificates.k8s.io] certificatesigningrequests',
      'create',
      'system:node-bootstrapper',
    ])
  })

  it('says a category word once, not twice', () => {
    // The "Group" node is followed by a node tagged "Group", and the sentence
    // says it once.
    expect(read(PATH).match(/Group/g)).toHaveLength(1)
    expect(read(PATH)).not.toContain('Group Group')
    expect(read(PATH)).not.toContain('resource resource')
  })

  it('grows as far down the path as it has been given', () => {
    expect(read(PATH.slice(0, 2))).toBe('Namespace kube-system admits Group')
    expect(read(PATH.slice(0, 1))).toBe('Namespace kube-system')
  })

  it('has nothing to say about an empty path', () => {
    expect(describe([])).toEqual([])
  })

  it('skips a node with no tag rather than leaving a gap', () => {
    expect(read([{ text: 'ClusterRole', tag: '' }, { text: 'cluster-admin', tag: 'ClusterRole' }]))
      .toBe('ClusterRole cluster-admin')
  })
})
