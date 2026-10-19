<script setup>
import { computed } from 'vue'
import { t } from '../i18n/index.js'

// Статус-бар панели: приоритет отображения — состояние обновления (стадии
// апдейтера из dialog.rb), затем выполняемая операция, затем подсказка
// по выделению/готовности.
const props = defineProps({
  // Последняя стадия апдейтера {stage, latest, current, percent, message, code}
  update: { type: Object, default: null },
  // Подсказка по выделению (когда ничего другого не происходит)
  hint: { type: String, default: '' },
  // Тон подсказки выделения: 'ok' — есть целевые объекты, 'warn' — нет
  hintTone: { type: String, default: 'warn' },
  // Текст выполняемой операции ('Выполняется поворот…') или ''
  busyHint: { type: String, default: '' }
})

const STAGE_STYLE = {
  checking: { dot: 'bg-sky-500 animate-pulse', text: 'text-slate-500 dark:text-slate-400' },
  found: { dot: 'bg-amber-500', text: 'text-amber-700 dark:text-amber-400' },
  downloading: { dot: 'bg-sky-500 animate-pulse', text: 'text-slate-500 dark:text-slate-400' },
  installing: { dot: 'bg-sky-500 animate-pulse', text: 'text-slate-500 dark:text-slate-400' },
  done: { dot: 'bg-emerald-500', text: 'text-emerald-700 dark:text-emerald-400' },
  current: { dot: 'bg-emerald-500', text: 'text-emerald-700 dark:text-emerald-400' },
  dismissed: { dot: 'bg-slate-300 dark:bg-slate-600', text: 'text-slate-500 dark:text-slate-400' },
  error: { dot: 'bg-red-500', text: 'text-red-600 dark:text-red-400' }
}

const stage = computed(() => (props.update && props.update.stage) || '')

const updateText = computed(() => {
  const u = props.update || {}
  switch (u.stage) {
    case 'checking':
      return t('status.checking')
    case 'found':
      return t('status.found', { latest: u.latest, current: u.current })
    case 'downloading':
      return t('status.downloading', { percent: u.percent ?? 0 })
    case 'installing':
      return t('status.installing')
    case 'done':
      return t('status.done')
    case 'current':
      return t('status.current', { current: u.current })
    case 'dismissed':
      return t('status.dismissed')
    case 'error':
      if (u.code === 'github_unreachable') return t('status.githubUnreachable')
      if (u.code === 'dev_copy') return t('status.devCopy')
      return t('status.error', { message: u.message || 'unknown' })
    default:
      return ''
  }
})

const text = computed(() => {
  if (stage.value) return updateText.value
  if (props.busyHint) return props.busyHint
  return props.hint
})

const dotClass = computed(() => {
  if (stage.value) return (STAGE_STYLE[stage.value] || STAGE_STYLE.dismissed).dot
  if (props.busyHint) return 'bg-sky-500 animate-pulse'
  return props.hintTone === 'ok' ? 'bg-sky-500' : 'bg-amber-500'
})

const textClass = computed(() => {
  if (stage.value) return (STAGE_STYLE[stage.value] || STAGE_STYLE.dismissed).text
  if (props.busyHint) return 'text-slate-500 dark:text-slate-400'
  return props.hintTone === 'ok' ? 'text-sky-700 dark:text-sky-400' : 'text-amber-700 dark:text-amber-400'
})

const percent = computed(() => (props.update && props.update.percent) || 0)
</script>

<template>
  <footer class="border-t border-slate-200 bg-white px-4 py-2 dark:border-slate-800 dark:bg-slate-900">
    <div
      v-if="stage === 'downloading'"
      class="mb-1.5 h-1 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800"
    >
      <div
        class="h-full rounded-full bg-sky-600 transition-all duration-300"
        :style="{ width: `${percent}%` }"
      ></div>
    </div>
    <div class="flex items-start gap-2 text-xs leading-snug">
      <span class="inline-block h-2 w-2 flex-none rounded-full" :class="dotClass"></span>
      <span class="min-w-0 flex-1" :class="textClass">{{ text }}</span>
    </div>
  </footer>
</template>
