<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { callRuby, onEvent } from './bridge.js'
import SectionBlock from './components/SectionBlock.vue'
import RotateParams from './components/RotateParams.vue'
import ViewsParams from './components/ViewsParams.vue'
import SchemeRotate from './components/SchemeRotate.vue'
import SchemeViews from './components/SchemeViews.vue'

const DEFAULTS = Object.freeze({
  angle_z: 35,
  angle_x: 35,
  make_copy: true,
  side_view: 'Справа',
  offset: '20%'
})

const version = ref('')
const settings = ref({ ...DEFAULTS })
const selection = ref({ total: 0, targets: 0 })
const busy = reactive({ rotate: false, views: false })
const toast = ref('')
let toastTimer = null
// Настройки грузятся асинхронно — до загрузки наблюдатели молчат,
// чтобы не сохранять/предпросматривать значения по умолчанию
let ready = false

const hasTargets = computed(() => selection.value.targets > 0)
const selectionText = computed(() => {
  const { total, targets } = selection.value
  if (targets > 0) return `Выделено объектов: ${targets} — предпросмотр и операции доступны`
  if (total > 0) return `Выделено: ${total}, но среди них нет компонентов или групп — выделите компонент или группу`
  return 'Выделите компонент или группу в модели'
})

function normalize(raw) {
  const s = raw && typeof raw === 'object' ? raw : {}
  const num = (v) => {
    const n = Number(String(v).replace(',', '.'))
    return Number.isFinite(n) ? n : DEFAULTS.angle_z
  }
  const side = s.side_view === 'Слева' ? 'Слева' : 'Справа'
  const offset = String(s.offset == null ? '' : s.offset).trim() || DEFAULTS.offset
  return {
    angle_z: num(s.angle_z == null ? DEFAULTS.angle_z : s.angle_z),
    angle_x: num(s.angle_x == null ? DEFAULTS.angle_x : s.angle_x),
    make_copy: s.make_copy !== false && s.make_copy !== 'Нет',
    side_view: side,
    offset
  }
}

function showToast(text) {
  toast.value = text
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => {
    toast.value = ''
  }, 2600)
}

function debounce(fn, ms) {
  let t = null
  return (...args) => {
    clearTimeout(t)
    t = setTimeout(() => fn(...args), ms)
  }
}

async function refreshSelection() {
  try {
    const info = await callRuby('selection_info')
    if (info && typeof info === 'object') selection.value = info
  } catch {
    /* мост недоступен — остаётся последнее состояние */
  }
}

// Страховочный опрос выделения: push от SelectionObserver — основной канал,
// но SU2026 (Qt WebEngine) может терять execute_script из колбэков наблюдателя.
// Опрос гарантирует, что индикатор и кнопки придут в актуальное состояние,
// даже если пуш-событие не дошло. Защита от наложения — один запрос за раз.
const POLL_MS = 1200
let pollTimer = null
let pollInFlight = false
async function pollSelection() {
  if (pollInFlight || document.visibilityState !== 'visible') return
  pollInFlight = true
  try {
    await refreshSelection()
  } finally {
    pollInFlight = false
  }
}

// Настройки применяются сразу: любое изменение тихо сохраняется в Ruby
// (ошибка — только тост), а параметры блоков обновляют живой 3D-предпросмотр
const saveSettings = debounce(async () => {
  try {
    await callRuby('settings_save', normalize(settings.value))
  } catch (e) {
    showToast(`Не сохранено: ${(e && e.message) || e}`)
  }
}, 400)

const updateRotatePreview = debounce(() => {
  callRuby('preview_update', normalize(settings.value))
}, 120)

const updateViewsPreview = debounce(() => {
  callRuby('preview_views_update', normalize(settings.value))
}, 120)

watch(
  () => [settings.value.angle_z, settings.value.angle_x, settings.value.make_copy],
  () => {
    if (!ready) return
    saveSettings()
    updateRotatePreview()
  }
)

watch(
  () => [settings.value.side_view, settings.value.offset],
  () => {
    if (!ready) return
    saveSettings()
    updateViewsPreview()
  }
)

// Выделение пропало — предпросмотр в модели больше не нужен
watch(hasTargets, (v) => {
  if (!v) callRuby('preview_cancel')
})

async function doApplyRotate() {
  busy.rotate = true
  try {
    await callRuby('preview_apply', normalize(settings.value))
    await refreshSelection()
    showToast('Поворот применён (Ctrl+Z — отмена)')
  } catch (e) {
    showToast(`Ошибка: ${(e && e.message) || e}`)
  } finally {
    busy.rotate = false
  }
}

async function doApplyViews() {
  busy.views = true
  try {
    await callRuby('preview_views_apply', normalize(settings.value))
    await refreshSelection()
    showToast('Проекции созданы (Ctrl+Z — отмена)')
  } catch (e) {
    showToast(`Ошибка: ${(e && e.message) || e}`)
  } finally {
    busy.views = false
  }
}

onMounted(async () => {
  // Ruby пушит состояние выделения в панель через SelectionObserver (dialog.rb)
  onEvent('selection', (info) => {
    if (info && typeof info === 'object') selection.value = info
  })
  try {
    const s = await callRuby('settings_get')
    if (s && typeof s === 'object') {
      settings.value = normalize(s)
      if (s.version) version.value = String(s.version)
    }
  } catch {
    /* мост недоступен — работаем на значениях по умолчанию */
  }
  ready = true
  refreshSelection()
  pollTimer = setInterval(pollSelection, POLL_MS)
  window.addEventListener('focus', pollSelection)
  document.addEventListener('visibilitychange', pollSelection)
})

onUnmounted(() => {
  clearInterval(pollTimer)
  window.removeEventListener('focus', pollSelection)
  document.removeEventListener('visibilitychange', pollSelection)
})
</script>

<template>
  <div class="flex h-full flex-col bg-slate-50 text-slate-800">
    <header class="flex items-center justify-between border-b border-slate-200 bg-white px-4 py-3">
      <div>
        <h1 class="text-sm font-semibold leading-tight text-slate-800">Comp Add View</h1>
        <p class="text-xs text-slate-500">DN1Sup · настройки применяются сразу</p>
      </div>
      <span class="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-500">
        {{ version ? `v${version}` : '·' }}
      </span>
    </header>

    <div class="flex-1 overflow-y-auto">
      <div class="px-4 pt-3">
        <div
          class="flex items-center gap-2 rounded-lg border px-3 py-2 text-xs"
          :class="hasTargets ? 'border-sky-200 bg-sky-50 text-sky-700' : 'border-amber-200 bg-amber-50 text-amber-700'"
        >
          <span class="inline-block h-2 w-2 flex-none rounded-full" :class="hasTargets ? 'bg-sky-500' : 'bg-amber-500'"></span>
          <span>{{ selectionText }}</span>
        </div>
      </div>

      <SectionBlock
        title="Поворот"
        description="Сначала поворот по Z, затем по X вокруг точки вставки. С копией — копия сдвигается влево на ширину объекта; без — поворот на месте."
        button-label="Применить"
        :busy="busy.rotate"
        :disabled="!hasTargets"
        @run="doApplyRotate"
      >
        <template #params>
          <RotateParams :settings="settings" />
        </template>
        <SchemeRotate :angle-z="settings.angle_z" :angle-x="settings.angle_x" :make-copy="settings.make_copy" />
      </SectionBlock>

      <SectionBlock
        title="Вид сверху и сбоку"
        description="Две копии-проекции: сверху (X +90°) и сбоку (Z ∓90°) с отступом от исходного объекта."
        button-label="Создать проекции"
        :busy="busy.views"
        :disabled="!hasTargets"
        @run="doApplyViews"
      >
        <template #params>
          <ViewsParams :settings="settings" />
        </template>
        <SchemeViews :side-view="settings.side_view" :offset="settings.offset" />
      </SectionBlock>
    </div>

    <div
      v-if="toast"
      class="pointer-events-none fixed bottom-3 left-4 right-4 rounded-lg bg-slate-800 px-3 py-2 text-center text-xs text-white shadow-lg"
    >
      {{ toast }}
    </div>
  </div>
</template>
