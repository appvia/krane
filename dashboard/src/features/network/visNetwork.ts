// The real vis-network, kept behind the factory the composable takes so the view
// can be tested without a canvas.

import { Network, type Data } from 'vis-network'

import type { NetworkFactory, NetworkHandle } from '@/features/network/useVisNetwork'

// vis-network and vis-data ship their own copies of the DataSet types, and the
// two do not line up, so the boundary is cast once here rather than everywhere.
export const createVisNetwork: NetworkFactory = (container, data, options) =>
  new Network(container, data as unknown as Data, options) as unknown as NetworkHandle
