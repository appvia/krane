import { Window } from 'happy-dom'

// Node 26 defines a `localStorage` global that stays undefined unless the
// process was started with --localstorage-file, and it shadows the one
// happy-dom installs. Borrow a working one from a throwaway window, since
// happy-dom's Storage cannot be constructed directly.
if (!globalThis.localStorage) {
  Object.defineProperty(globalThis, 'localStorage', {
    value: new Window().localStorage,
    configurable: true,
  })
}
