<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { Globe, Moon, Sun } from 'lucide-vue-next'
import { callRuby, onEvent } from './bridge.js'
import { locale, setLocale, t } from './i18n/index.js'
import { applyTheme, isDark, toggleTheme } from './composables/useTheme.js'
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
const busy = reactive({ apply: false })
// Галочки в заголовках секций выбирают, какие операции выполнит кнопка
// «Применить»; обе включены по умолчанию
const applyRotate = ref(true)
const applyViews = ref(true)
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
// Применить можно, если есть цели и отмечена хотя бы одна операция
const canApply = computed(() => hasTargets.value && (applyRotate.value || applyViews.value))
const applying = computed(() => busy.apply)
const applyHint = computed(() => {
  if (!hasTargets.value) return t('apply.hintNoTargets')
  if (applyRotate.value && applyViews.value) return t('apply.hintBoth')
  if (applyRotate.value) return t('apply.hintRotate')
  if (applyViews.value) return t('apply.hintViews')
  return t('apply.hintNone')
})
const selectionText = computed(() => {
  const { total, targets } = selection.value
  if (targets > 0) return t('selection.targets', { targets })
  if (total > 0) return t('selection.noTargets', { total })
  return t('selection.empty')
})

// Обновление считается идущим, пока апдейтер в активной стадии — крутится
// спиннер кнопки в шапке
const updateBusy = computed(() =>
  ['checking', 'downloading', 'installing'].includes(updateStatus.value?.stage)
)

// Подсказка выполняемой операции для статус-бара ('' — ничего не выполняется)
const busyHint = computed(() => (busy.apply ? t('busy.applying') : ''))

// Язык: кнопка показывает ЦЕЛЕВОЙ язык (как в export_pdf2 / time_project)
const langTarget = computed(() => (locale.value === 'ru' ? 'EN' : 'RU'))
const langTitle = computed(() => (locale.value === 'ru' ? t('lang.toEn') : t('lang.toRu')))
const themeTitle = computed(() => (isDark.value ? t('theme.toLight') : t('theme.toDark')))

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

// Полный payload для settings_save: геометрия + UI-предпочтения
// (язык/тема — источник истины settings.yaml, localStorage — кэш)
function fullPayload() {
  return {
    ...normalize(settings.value),
    language: locale.value,
    theme: isDark.value ? 'dark' : 'light'
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
    await callRuby('settings_save', fullPayload())
  } catch (e) {
    showToast(t('toast.notSaved', { message: (e && e.message) || e }))
  }
}, 400)

// 60 мс — слайдеры обновляют 3D-предпросмотр в модели практически без задержки
const updateRotatePreview = debounce(() => {
  callRuby('preview_update', normalize(settings.value))
}, 60)

const updateViewsPreview = debounce(() => {
  callRuby('preview_views_update', normalize(settings.value))
}, 60)

// Отступ влияет на обе операции (и на копию «Поворота», и на проекции):
// слайдер отступа обновляет предпросмотр того блока, который пользователь
// редактировал последним
const lastBlock = ref('rotate')

watch(
  () => [settings.value.angle_z, settings.value.angle_x, settings.value.make_copy, settings.value.rot180],
  () => {
    if (!ready) return
    lastBlock.value = 'rotate'
    saveSettings()
    updateRotatePreview()
  }
)

watch(
  () => settings.value.side_view,
  () => {
    if (!ready) return
    lastBlock.value = 'views'
    saveSettings()
    updateViewsPreview()
  }
)

watch(
  () => settings.value.offset,
  () => {
    if (!ready) return
    saveSettings()
    lastBlock.value === 'rotate' ? updateRotatePreview() : updateViewsPreview()
  }
)

// Выделение пропало — предпросмотр в модели больше не нужен
watch(hasTargets, (v) => {
  if (!v) callRuby('preview_cancel')
})

// Смена языка/темы из шапки: применяется сразу и сохраняется в settings.yaml
function switchLanguage() {
  setLocale(locale.value === 'ru' ? 'en' : 'ru')
  if (!ready) return
  saveSettings()
}

function switchTheme() {
  toggleTheme()
  if (!ready) return
  saveSettings()
}

// Общее «Применить»: отмеченные галочками операции выполняются над одним и
// тем же выделением — Ruby (Preview.apply_many) восстанавливает выделение
// между шагами, поэтому проекции создаются от исходного объекта, а не от
// копии поворота. Каждая операция — отдельный шаг Ctrl+Z.
async function doApply() {
  if (!canApply.value || busy.apply) return
  const kinds = []
  if (applyRotate.value) kinds.push('rotate')
  if (applyViews.value) kinds.push('views')
  busy.apply = true
  try {
    const res = await callRuby('preview_apply_many', { kinds, ...normalize(settings.value) })
    await refreshSelection()
    // ok:false — Ruby не смог выполнить (обычно нет подходящего выделения)
    if (res && res.ok === false) {
      showToast(t('toast.notDone'))
      return
    }
    showToast(
      kinds.length === 2
        ? t('toast.appliedBoth')
        : kinds[0] === 'rotate'
          ? t('toast.appliedRotate')
          : t('toast.appliedViews')
    )
  } catch (e) {
    showToast(t('toast.error', { message: (e && e.message) || e }))
  } finally {
    busy.apply = false
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
    if (st.stage === 'done') showToast(t('toast.updateDone'))
  })
  try {
    const s = await callRuby('settings_get')
    if (s && typeof s === 'object') {
      settings.value = fromRuby(s)
      if (s.version) version.value = String(s.version)
      if (s.language) setLocale(s.language)
      if (s.theme) applyTheme(String(s.theme).toLowerCase() === 'dark')
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
  <div class="flex h-full flex-col bg-slate-50 text-slate-800 dark:bg-slate-900 dark:text-slate-200">
    <header class="flex items-center justify-between border-b border-slate-200 bg-white px-4 py-3 dark:border-slate-800 dark:bg-slate-900">
      <div class="flex items-center gap-2.5 min-w-0">
        <img src="./assets/logo.svg" width="28" height="28" class="shrink-0" alt="DN1Sup Comp Add View">
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <h1 class="text-sm font-semibold leading-tight text-slate-800 dark:text-slate-100">DN1Sup Comp Add View</h1>
            <span v-if="version" class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-500">v{{ version }}</span>
          </div>
          <p class="text-xs text-slate-500 dark:text-slate-400">{{ t('header.subtitle') }}</p>
        </div>
      </div>
      <div class="flex items-center gap-1.5">
        <button
          type="button"
          :title="t('header.helpTitle')"
          :aria-label="t('header.helpTitle')"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-sky-600 dark:text-slate-500 dark:hover:bg-slate-800 dark:hover:text-sky-400"
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
          :title="t('header.checkUpdateTitle')"
          :aria-label="t('header.checkUpdateTitle')"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-sky-600 dark:text-slate-500 dark:hover:bg-slate-800 dark:hover:text-sky-400"
          @click="checkUpdate"
        >
          <svg class="h-4 w-4" :class="{ 'animate-spin': updateBusy }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8" />
            <path d="M21 3v5h-5" />
          </svg>
        </button>
        <button
          type="button"
          :title="themeTitle"
          :aria-label="themeTitle"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-sky-600 dark:text-slate-500 dark:hover:bg-slate-800 dark:hover:text-sky-400"
          @click="switchTheme"
        >
          <Sun v-if="isDark" class="h-4 w-4" />
          <Moon v-else class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="flex items-center gap-1 rounded-md border border-slate-200 px-2 py-0.5 text-[11px] font-semibold uppercase text-slate-500 transition-colors hover:text-slate-700 dark:border-slate-700 dark:text-slate-400 dark:hover:text-slate-200"
          :title="langTitle"
          :aria-label="langTitle"
          @click="switchLanguage"
        >
          <Globe class="h-3.5 w-3.5 text-slate-400 dark:text-slate-500" />
          {{ langTarget }}
        </button>
      </div>
    </header>

    <div class="flex-1 overflow-y-auto">
      <!-- Единый эскиз обеих операций: реагирует на все параметры в реальном времени -->
      <div class="mx-4 mt-3 overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900">
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
        :title="t('section.rotate.title')"
        :description="t('section.rotate.desc')"
      >
        <template #title>
          <label class="flex cursor-pointer items-center gap-2.5">
            <input v-model="applyRotate" type="checkbox" class="h-4 w-4 rounded border-slate-300 accent-sky-600 dark:border-slate-600" />
            <span class="text-sm font-semibold text-slate-800 dark:text-slate-100">{{ t('section.rotate.title') }}</span>
          </label>
        </template>
        <template #params>
          <RotateParams :settings="settings" />
        </template>
      </SectionBlock>

      <SectionBlock
        :title="t('section.views.title')"
        :description="t('section.views.desc')"
      >
        <template #title>
          <label class="flex cursor-pointer items-center gap-2.5">
            <input v-model="applyViews" type="checkbox" class="h-4 w-4 rounded border-slate-300 accent-sky-600 dark:border-slate-600" />
            <span class="text-sm font-semibold text-slate-800 dark:text-slate-100">{{ t('section.views.title') }}</span>
          </label>
        </template>
        <template #params>
          <ViewsParams :settings="settings" />
        </template>
      </SectionBlock>

      <!-- Общая кнопка применения: выполняет отмеченные галочками операции -->
      <section class="mx-4 mt-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900">
        <button
          type="button"
          class="w-full rounded-lg bg-sky-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-sky-700 active:bg-sky-800 disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="!canApply || applying"
          @click="doApply"
        >
          {{ applying ? t('apply.running') : t('apply.button') }}
        </button>
        <p class="mt-2 text-center text-xs text-slate-400 dark:text-slate-500">{{ applyHint }}</p>
      </section>
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
      class="pointer-events-none fixed bottom-12 left-4 right-4 rounded-lg bg-slate-800 px-3 py-2 text-center text-xs text-white shadow-lg dark:bg-slate-700"
    >
      {{ toast }}
    </div>

    <HelpDialog v-if="helpOpen" :version="version" @close="helpOpen = false" />
  </div>
</template>
