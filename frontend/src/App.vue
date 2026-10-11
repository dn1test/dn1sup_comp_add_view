<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { callRuby, onEvent } from './bridge.js'
import ActionCard from './components/ActionCard.vue'
import SchemeRotate from './components/SchemeRotate.vue'
import SchemeViews from './components/SchemeViews.vue'
import SettingsForm from './components/SettingsForm.vue'

const DEFAULTS = Object.freeze({
  angle_z: 35,
  angle_x: 35,
  make_copy: true,
  side_view: 'Справа',
  offset: '20%'
})

const version = ref('')
const applied = ref({ ...DEFAULTS })
const draft = ref({ ...DEFAULTS })
const selection = ref({ total: 0, targets: 0 })
const busy = reactive({ rotate: false, views: false, save: false })
const toast = ref('')
let toastTimer = null

const hasTargets = computed(() => selection.value.targets > 0)
const selectionText = computed(() =>
  hasTargets.value
    ? `Выделено объектов: ${selection.value.targets} — операции доступны`
    : 'Выделите компонент или группу в модели'
)
const dirty = computed(() => JSON.stringify(normalize(draft.value)) !== JSON.stringify(normalize(applied.value)))

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

async function refreshSelection() {
  try {
    const info = await callRuby('selection_info')
    if (info && typeof info === 'object') selection.value = info
  } catch {
    /* мост недоступен — остаётся последнее состояние */
  }
}

async function doRotate() {
  busy.rotate = true
  try {
    await callRuby('rotate')
    await refreshSelection()
    showToast('Поворот выполнен (Ctrl+Z — отмена)')
  } catch (e) {
    showToast(`Ошибка: ${(e && e.message) || e}`)
  } finally {
    busy.rotate = false
  }
}

async function doViews() {
  busy.views = true
  try {
    await callRuby('views')
    await refreshSelection()
    showToast('Проекции созданы (Ctrl+Z — отмена)')
  } catch (e) {
    showToast(`Ошибка: ${(e && e.message) || e}`)
  } finally {
    busy.views = false
  }
}

async function save() {
  busy.save = true
  try {
    const payload = normalize(draft.value)
    const fresh = await callRuby('settings_save', payload)
    applied.value = normalize(fresh && fresh.angle_z !== undefined ? fresh : payload)
    draft.value = { ...applied.value }
    showToast('Настройки сохранены')
  } catch (e) {
    showToast(`Не сохранено: ${(e && e.message) || e}`)
  } finally {
    busy.save = false
  }
}

function reset() {
  draft.value = { ...DEFAULTS }
  showToast('Значения по умолчанию (не забудьте сохранить)')
}

onMounted(async () => {
  // Ruby пушит состояние выделения в панель через SelectionObserver (dialog.rb)
  onEvent('selection', (info) => {
    if (info && typeof info === 'object') selection.value = info
  })
  try {
    const s = await callRuby('settings_get')
    if (s && typeof s === 'object') {
      applied.value = normalize(s)
      draft.value = { ...applied.value }
      if (s.version) version.value = String(s.version)
    }
  } catch {
    /* мост недоступен — работаем на значениях по умолчанию */
  }
  refreshSelection()
})
</script>

<template>
  <div class="flex h-full flex-col bg-slate-50 text-slate-800">
    <header class="flex items-center justify-between border-b border-slate-200 bg-white px-4 py-3">
      <div>
        <h1 class="text-sm font-semibold leading-tight text-slate-800">Comp Add View</h1>
        <p class="text-xs text-slate-500">DN1Sup · панель управления</p>
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

      <ActionCard
        title="Повернуть"
        description="Копия сдвигается влево на ширину объекта и поворачивается: сначала вокруг оси Z, затем вокруг X. Без копии — поворот на месте."
        button-label="Повернуть"
        :busy="busy.rotate"
        :disabled="!hasTargets"
        @run="doRotate"
      >
        <SchemeRotate :angle-z="draft.angle_z" :angle-x="draft.angle_x" :make-copy="draft.make_copy" />
      </ActionCard>

      <ActionCard
        title="Вид сверху и сбоку"
        description="Создаёт две копии-проекции: сверху (поворот X +90°) и сбоку (поворот Z ∓90°) с отступом от исходного объекта."
        button-label="Создать проекции"
        :busy="busy.views"
        :disabled="!hasTargets"
        @run="doViews"
      >
        <SchemeViews :side-view="draft.side_view" :offset="draft.offset" />
      </ActionCard>

      <SettingsForm :draft="draft" :dirty="dirty" :busy="busy.save" @save="save" @reset="reset" />
    </div>

    <div
      v-if="toast"
      class="pointer-events-none fixed bottom-3 left-4 right-4 rounded-lg bg-slate-800 px-3 py-2 text-center text-xs text-white shadow-lg"
    >
      {{ toast }}
    </div>
  </div>
</template>
