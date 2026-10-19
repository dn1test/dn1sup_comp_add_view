// Тема панели (светлая/тёмная), паттерн соседних расширений
// (dn1sup_export_pdf2 / dn1sup_time_project useTheme.js).
// Свой ключ localStorage, чтобы не пересекаться с соседями;
// источник истины — settings.yaml (Ruby), localStorage — кэш для
// мгновенного старта без мерцания до прихода settings_get.

import { ref } from 'vue'

const STORAGE_KEY = 'dn1sup_comp_add_view_theme'

const isDark = ref(false)

export { isDark }

function applyTheme(dark) {
  isDark.value = Boolean(dark)
  if (typeof document !== 'undefined' && document.documentElement) {
    document.documentElement.classList.toggle('dark', isDark.value)
  }
  try {
    localStorage.setItem(STORAGE_KEY, isDark.value ? 'dark' : 'light')
  } catch {
    // CEF может запрещать localStorage — тема просто не переживёт перезапуск
  }
}

function toggleTheme() {
  applyTheme(!isDark.value)
}

// Синхронное чтение для старта без мерцания (вызывается из main.js до mount)
function initTheme() {
  let dark = false
  try {
    dark = localStorage.getItem(STORAGE_KEY) === 'dark'
  } catch {
    dark = false
  }
  applyTheme(dark)
}

export function useTheme() {
  return { isDark, toggleTheme, applyTheme, initTheme }
}

export { applyTheme, toggleTheme, initTheme }
