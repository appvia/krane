import js from '@eslint/js'
import pluginVue from 'eslint-plugin-vue'
import globals from 'globals'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  {
    // The 2021 stack still lives here until the teardown commit removes it.
    ignores: [
      'compiled/**',
      'node_modules/**',
      'gulpfile.js',
      'src/js/**',
      'src/scss/**',
      'src/html/**',
    ],
  },
  js.configs.recommended,
  tseslint.configs.recommended,
  pluginVue.configs['flat/recommended'],
  {
    files: ['src/**/*.{ts,vue}'],
    languageOptions: { globals: globals.browser },
  },
  {
    files: ['src/workers/**/*.ts'],
    languageOptions: { globals: globals.worker },
  },
  {
    files: ['scripts/**/*.mjs', 'vite.config.ts', 'eslint.config.js'],
    languageOptions: { globals: globals.node },
  },
  {
    files: ['**/*.vue'],
    languageOptions: { parserOptions: { parser: tseslint.parser } },
  },
  {
    rules: {
      // Every string the dashboard renders comes from cluster RBAC, which is
      // attacker influenced. Escape-by-default templating is the whole reason
      // this app is Vue; v-html would hand that back.
      'vue/no-v-html': 'error',
      'vue/multi-word-component-names': 'off',
    },
  },
)
