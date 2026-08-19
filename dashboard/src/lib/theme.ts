import { ref, watch } from 'vue'

import { readSetting, writeSetting } from '@/lib/storage'

export type Theme = 'light' | 'dark'

const STORAGE_KEY = 'krane.theme'

function storedTheme(): Theme | null {
  const value = readSetting(STORAGE_KEY)
  return value === 'light' || value === 'dark' ? value : null
}

function systemTheme(): Theme {
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

const theme = ref<Theme>(storedTheme() ?? systemTheme())

function apply(value: Theme): void {
  document.documentElement.dataset.theme = value
}

// Applied on import rather than on mount, so the first paint is already themed.
apply(theme.value)

watch(theme, (value) => {
  apply(value)
  writeSetting(STORAGE_KEY, value)
})

export function useTheme() {
  return {
    theme,
    toggle: () => {
      theme.value = theme.value === 'dark' ? 'light' : 'dark'
    },
  }
}
