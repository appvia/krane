// Storage access can throw (private browsing, disabled storage) and the global
// is absent outside a browser, so every read and write goes through here. A
// preference that does not survive a reload is not worth failing a render over.

export function readSetting(key: string): string | null {
  try {
    return window.localStorage.getItem(key)
  } catch {
    return null
  }
}

export function writeSetting(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value)
  } catch {
    // nothing useful to do: the setting simply will not persist
  }
}
