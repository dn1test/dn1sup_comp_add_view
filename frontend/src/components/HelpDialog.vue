<script setup>
import { onMounted, onUnmounted } from 'vue'
import { callRuby } from '../bridge.js'

// Модальная справка по расширению (кнопка «?» в шапке панели).
const props = defineProps({
  version: { type: String, default: '' }
})
const emit = defineEmits(['close'])

function onKey(e) {
  if (e.key === 'Escape') emit('close')
}
onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => window.removeEventListener('keydown', onKey))

function openReleases() {
  callRuby('open_releases')
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4"
    @click.self="emit('close')"
  >
    <div class="max-h-full w-full max-w-md overflow-y-auto rounded-xl bg-white shadow-xl">
      <header class="flex items-center justify-between border-b border-slate-200 px-4 py-3">
        <h2 class="text-sm font-semibold text-slate-800">Справка · Comp Add View</h2>
        <button
          type="button"
          title="Закрыть"
          aria-label="Закрыть справку"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600"
          @click="emit('close')"
        >
          <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 6 6 18" />
            <path d="m6 6 12 12" />
          </svg>
        </button>
      </header>

      <div class="space-y-4 px-4 py-3 text-xs leading-relaxed text-slate-600">
        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800">Что делает</h3>
          <p>
            Дублирует выделенные компоненты и группы. «Поворот» — копия сдвигается
            влево на ширину объекта (или поворот на месте) и поворачивается вокруг
            точки вставки: сначала вокруг Z (30–70°, тумблером +180°), затем вокруг X
            (30–70°). «Вид сверху и сбоку» — создаёт копии-проекции: над объектом и
            справа (или слева) от него с заданным отступом в процентах.
          </p>
        </section>

        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800">Порядок работы</h3>
          <ol class="list-decimal space-y-1 pl-4">
            <li>Выделите в модели компонент или группу.</li>
            <li>
              Настройте параметры — схема в панели и 3D-предпросмотр в модели
              обновляются сразу.
            </li>
            <li>
              Нажмите «Применить» или «Создать проекции». Отмена — Ctrl+Z;
              предпросмотр снимается сам при смене выделения или инструмента.
            </li>
          </ol>
        </section>

        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800">Настройки</h3>
          <p>
            Сохраняются автоматически и применяются сразу — отдельного диалога
            настроек нет.
          </p>
        </section>

        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800">Обновления</h3>
          <p>
            Круговая кнопка в шапке проверяет релизы на GitHub; статус проверки и
            установки показывается в строке состояния внизу панели. После установки
            обновления перезапустите SketchUp.
          </p>
        </section>
      </div>

      <footer class="flex items-center justify-between border-t border-slate-200 px-4 py-3 text-xs">
        <span class="text-slate-400">DN1Sup{{ version ? ` · версия ${version}` : '' }}</span>
        <button
          type="button"
          class="font-medium text-sky-600 transition-colors hover:text-sky-700"
          @click="openReleases"
        >
          Страница релизов на GitHub
        </button>
      </footer>
    </div>
  </div>
</template>
