<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { callRuby, onEvent } from './bridge.js'
import SectionBlock from './components/SectionBlock.vue'
import RotateParams from './components/RotateParams.vue'
import ViewsParams from './components/ViewsParams.vue'
import SchemeCombined from './components/SchemeCombined.vue'
import StatusBar from './components/StatusBar.vue'
import HelpDialog from './components/HelpDialog.vue'

const DEFAULTS = Object.freeze({
  angle_z: 35,
  angle_x: 35,
  make_copy: true,
  side_view: 'Справа',
  offset: 20, // проценты; в Ruby уходит строкой «20%»
  rot180: false
})

const version = ref('')
const settings = ref({ ...DEFAULTS })
const selection = ref({ total: 0, targets: 0 })
const busy = reactive({ rotate: false, views: false })
const toast = ref('')
// Последняя стадия апдейтера ({stage, latest, current, percent, message, code});
// приходит событием 'update_status' из dialog.rb (status_cb проверки обновлений)
const updateStatus = ref(null)
const helpOpen = ref(false)
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

// Обновление считается идущим, пока апдейтер в активной стадии — крутится
// спиннер кнопки в шапке
const updateBusy = computed(() =>
  ['checking', 'downloading', 'installing'].includes(updateStatus.value?.stage)
)

// Подсказка выполняемой операции для статус-бара ('' — ничего не выполняется)
const busyHint = computed(() => {
  if (busy.rotate) return 'Выполняется поворот…'
  if (busy.views) return 'Создаются проекции…'
  return ''
})

function clampPercent(v) {
  const n = Number(String(v == null ? '' : v).replace(',', '.'))
  const pct = Number.isFinite(n) && n > 0 ? Math.round(n) : DEFAULTS.offset
  return Math.min(200, Math.max(1, pct))
}

// Углы работают в диапазоне 30–70°: слайдеры — весь диапазон, числовые поля
// и значения из старых настроек приводятся к нему; разворот сверх диапазона —
// тумблер «+180° к Z»
function clampAngle(v) {
  const n = Number(String(v == null ? '' : v).replace(',', '.'))
  const a = Number.isFinite(n) ? Math.round(n) : DEFAULTS.angle_z
  return Math.min(70, Math.max(30, a))
}

// Формат для Ruby: offset строкой «N%», как его понимает Rotator.calculate_gap
function normalize(raw) {
  const s = raw && typeof raw === 'object' ? raw : {}
  return {
    angle_z: clampAngle(s.angle_z == null ? DEFAULTS.angle_z : s.angle_z),
    angle_x: clampAngle(s.angle_x == null ? DEFAULTS.angle_x : s.angle_x),
    make_copy: s.make_copy !== false && s.make_copy !== 'Нет',
    side_view: s.side_view === 'Слева' ? 'Слева' : 'Справа',
    offset: `${clampPercent(s.offset)}%`,
    rot180: s.rot180 === true || s.rot180 === 'true'
  }
}

// Значения из Ruby: offset приходит строкой «20%»; мм-значение без «%» —
// наследие старого текстового поля, панель работает только в процентах
function fromRuby(raw) {
  const parsed = normalize(raw)
  const s = raw && typeof raw === 'object' ? raw : {}
  const m = /^(\d+(?:[.,]\d+)?)\s*%$/.exec(String(s.offset == null ? '' : s.offset).trim())
  parsed.offset = m ? clampPercent(m[1]) : DEFAULTS.offset
  return parsed
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

// 60 мс — слайдеры обновляют 3D-предпросмотр в модели практически без задержки
const updateRotatePreview = debounce(() => {
  callRuby('preview_update', normalize(settings.value))
}, 60)

const updateViewsPreview = debounce(() => {
  callRuby('preview_views_update', normalize(settings.value))
}, 60)

watch(
  () => [settings.value.angle_z, settings.value.angle_x, settings.value.make_copy, settings.value.rot180],
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

// Проверка обновления: релиз на GitHub.
function checkUpdate() {
  callRuby('check_update')
}

onMounted(async () => {
  // Ruby пушит состояние выделения в панель через SelectionObserver (dialog.rb)
  onEvent('selection', (info) => {
    if (info && typeof info === 'object') selection.value = info
  })
  // Стадии проверки/установки обновления (status_cb апдейтера → dialog.rb).
  // «done» означает «native messagebox подавлен» — дублируем тостом.
  onEvent('update_status', (st) => {
    if (!st || typeof st !== 'object') return
    updateStatus.value = st
    if (st.stage === 'done') showToast('Обновление установлено — перезапустите SketchUp')
  })
  try {
    const s = await callRuby('settings_get')
    if (s && typeof s === 'object') {
      settings.value = fromRuby(s)
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
      <div class="flex items-center gap-2.5 min-w-0">
        <img src="./assets/logo.svg" width="28" height="28" class="shrink-0" alt="DN1Sup Comp Add View">
        <div>
          <h1 class="text-sm font-semibold leading-tight text-slate-800">Comp Add View</h1>
          <p class="text-xs text-slate-500">DN1Sup · настройки применяются сразу</p>
        </div>
      </div>
      <div class="flex items-center gap-1.5">
        <button
          type="button"
          title="Справка"
          aria-label="Справка"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-sky-600"
          @click="helpOpen = true"
        >
          <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10" />
            <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
            <path d="M12 17h.01" />
          </svg>
        </button>
        <button
          type="button"
          title="Проверить обновление (GitHub Releases)"
          aria-label="Проверить обновление"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-sky-600"
          @click="checkUpdate"
        >
          <svg class="h-4 w-4" :class="{ 'animate-spin': updateBusy }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8" />
            <path d="M21 3v5h-5" />
          </svg>
        </button>
        <span class="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-500">
          {{ version ? `v${version}` : '·' }}
        </span>
      </div>
    </header>

    <div class="flex-1 overflow-y-auto">
      <!-- Единый эскиз обеих операций: реагирует на все параметры в реальном времени -->
      <div class="mx-4 mt-3 overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
        <SchemeCombined
          :angle-z="settings.angle_z"
          :angle-x="settings.angle_x"
          :make-copy="settings.make_copy"
          :side-view="settings.side_view"
          :offset-percent="settings.offset"
          :rot180="settings.rot180"
        />
      </div>

      <SectionBlock
        title="Поворот"
        description="Копия сдвигается влево на ширину объекта (или поворот на месте), затем поворот вокруг точки вставки: сначала Z (30–70°, тумблером +180°), затем X (30–70°)."
        button-label="Применить"
        :busy="busy.rotate"
        :disabled="!hasTargets"
        @run="doApplyRotate"
      >
        <template #params>
          <RotateParams :settings="settings" />
        </template>
      </SectionBlock>

      <SectionBlock
        title="Вид сверху и сбоку"
        description="Копия «вид сверху» ставится над объектом, копия «вид сбоку» — справа; отступ задаётся в процентах. Переключатель выбирает направление взгляда: вид справа (Z −90°) или слева (Z +90°)."
        button-label="Создать проекции"
        :busy="busy.views"
        :disabled="!hasTargets"
        @run="doApplyViews"
      >
        <template #params>
          <ViewsParams :settings="settings" />
        </template>
      </SectionBlock>
    </div>

    <!-- Статус-бар: состояние обновления, выполняемая операция, подсказка по выделению -->
    <StatusBar
      :update="updateStatus"
      :hint="selectionText"
      :hint-tone="hasTargets ? 'ok' : 'warn'"
      :busy-hint="busyHint"
    />

    <div
      v-if="toast"
      class="pointer-events-none fixed bottom-12 left-4 right-4 rounded-lg bg-slate-800 px-3 py-2 text-center text-xs text-white shadow-lg"
    >
      {{ toast }}
    </div>

    <HelpDialog v-if="helpOpen" :version="version" @close="helpOpen = false" />
  </div>
</template>
