<script setup>
// Параметры блока «Проекции»: мутируют объект settings родителя по ссылке.
import { computed } from 'vue'
import { t } from '../i18n/index.js'

defineProps({
  settings: { type: Object, required: true }
})

// Внутренние значения side_view остаются русскими ('Справа'/'Слева')
// для совместимости с settings.yaml и Ruby; в UI показываем перевод.
const SIDES = computed(() => [
  { value: 'Справа', label: t('views.sideRight') },
  { value: 'Слева', label: t('views.sideLeft') }
])
</script>

<template>
  <div class="space-y-2.5">
    <div class="flex items-center justify-between text-sm text-slate-700 dark:text-slate-300">
      <span>{{ t('views.sideLabel') }}</span>
      <div class="flex rounded-lg border border-slate-200 p-0.5 dark:border-slate-700">
        <button
          v-for="s in SIDES"
          :key="s.value"
          type="button"
          class="rounded-md px-3 py-1 text-xs font-medium transition"
          :class="settings.side_view === s.value ? 'bg-sky-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800'"
          @click="settings.side_view = s.value"
        >
          {{ s.label }}
        </button>
      </div>
    </div>

    <!-- Отступ в процентах от габарита: слайдер — быстрый подбор,
         число — точное значение (до 200%); в Ruby уходит строкой «N%» -->
    <div class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300">
      <span class="w-14 flex-none">{{ t('views.offset') }}</span>
      <input
        v-model.number="settings.offset"
        type="range"
        min="1"
        max="100"
        step="1"
        class="min-w-0 flex-1 accent-sky-600"
      />
      <input
        v-model.number="settings.offset"
        type="number"
        min="1"
        max="200"
        step="1"
        class="w-14 flex-none rounded-md border border-slate-300 bg-white px-2 py-1 text-right text-xs tabular-nums focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200"
      />
      <span class="flex-none text-xs text-slate-400 dark:text-slate-500">%</span>
    </div>
  </div>
</template>
