import { beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'

async function loadTheme() {
  vi.resetModules()
  return import('./theme')
}

function prefersDark(matches: boolean) {
  vi.stubGlobal(
    'matchMedia',
    vi.fn(() => ({ matches })),
  )
}

describe('useTheme', () => {
  beforeEach(() => {
    window.localStorage.clear()
    delete document.documentElement.dataset.theme
    prefersDark(false)
  })

  it('follows the system preference when nothing has been chosen', async () => {
    prefersDark(true)
    const { useTheme } = await loadTheme()

    expect(useTheme().theme.value).toBe('dark')
  })

  it('prefers a stored choice over the system preference', async () => {
    prefersDark(true)
    window.localStorage.setItem('krane.theme', 'light')
    const { useTheme } = await loadTheme()

    expect(useTheme().theme.value).toBe('light')
  })

  it('marks the document on load, so the first paint is already themed', async () => {
    prefersDark(true)
    await loadTheme()

    expect(document.documentElement.dataset.theme).toBe('dark')
  })

  it('remarks the document and stores the choice when toggled', async () => {
    const { useTheme } = await loadTheme()
    useTheme().toggle()
    await nextTick()

    expect(document.documentElement.dataset.theme).toBe('dark')
    expect(window.localStorage.getItem('krane.theme')).toBe('dark')
  })

  it('still resolves a theme when storage is unavailable', async () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('denied')
    })

    const { useTheme } = await loadTheme()

    expect(useTheme().theme.value).toBe('light')
  })
})
