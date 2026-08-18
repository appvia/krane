import { createApp } from 'vue'

import App from './App.vue'
import { router } from './router'
import './lib/theme' // applies the stored theme before the first paint
import './styles/main.css'

createApp(App).use(router).mount('#app')
