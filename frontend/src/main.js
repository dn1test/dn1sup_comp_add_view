import { createApp } from 'vue'
import App from './App.vue'
import './style.css'
import { initTheme } from './composables/useTheme.js'
import { setLocale, currentLocale } from './i18n/index.js'

// Применяем кэшированные тему/язык до mount, чтобы панель не мерцала
initTheme()
setLocale(currentLocale())

createApp(App).mount('#app')
