// A path through the RBAC tree reads as a sentence, because the builder tags
// each level with the word that joins it to the next: a namespace "admits" a
// group, "to" a resource, with an "action", "defined by ClusterRole" X.
//
// Reading a leaf's ancestors back in order is what turns a position in a tree
// into a statement about who can do what.

export type SentencePart = {
  text: string
  /** A name from the cluster, rather than one of the joining words. */
  subject: boolean
}

export type SentenceNode = {
  text: string
  /** The node's first tag, which is the word joining it to its parent. */
  tag: string
}

export function describe(nodes: readonly SentenceNode[]): SentencePart[] {
  const parts: SentencePart[] = []
  let previous = ''

  nodes.forEach((node, index) => {
    // A tag that repeats the text above it would stutter: "Group Group".
    if (node.tag !== '' && node.tag !== previous) {
      parts.push({ text: node.tag, subject: false })
    }

    if (node.text !== '') {
      // A node whose text is the next node's tag is a category word, not a name
      // — "resource" in "to resource [core] pods".
      parts.push({ text: node.text, subject: nodes[index + 1]?.tag !== node.text })
    }

    previous = node.text
  })

  return parts
}
