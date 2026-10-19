<script setup>
// Параметры блока «Поворот»: мутируют объект settings родителя по ссылке —
// реактивность и автосохранение обрабатываются в App.vue.
import { t } from '../i18n/index.js'

defineProps({
  settings: { type: Object, required: true }
})
</script>

<template>
  <div class="space-y-2.5">
    <label class="flex items-center justify-between text-sm text-slate-700 dark:text-slate-300">
      <span>{{ t('rotate.copyLeft') }}</span>
      <button
        type="button"
        role="switch"
        :aria-checked="settings.make_copy"
        class="relative inline-flex h-5 w-9 flex-none items-center rounded-full transition"
        :class="settings.make_copy ? 'bg-sky-600' : 'bg-slate-300 dark:bg-slate-700'"
        @click="settings.make_copy = !settings.make_copy"
      >
        <span
          class="inline-block h-4 w-4 transform rounded-full bg-white shadow transition"
          :class="settings.make_copy ? 'translate-x-4' : 'translate-x-1'"
        ></span>
      </button>
    </label>

    <label class="flex items-center justify-between text-sm text-slate-700 dark:text-slate-300">
      <span>{{ t('rotate.rot180') }}</span>
      <button
        type="button"
        role="switch"
        :aria-checked="settings.rot180"
        class="relative inline-flex h-5 w-9 flex-none items-center rounded-full transition"
        :class="settings.rot180 ? 'bg-sky-600' : 'bg-slate-300 dark:bg-slate-700'"
        @click="settings.rot180 = !settings.rot180"
      >
        <span
          class="inline-block h-4 w-4 transform rounded-full bg-white shadow transition"
          :class="settings.rot180 ? 'translate-x-4' : 'translate-x-1'"
        ></span>
      </button>
    </label>

    <div class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300">
      <span class="w-14 flex-none">{{ t('rotate.angleZ') }}</span>
      <input
        v-model.number="settings.angle_z"
        type="range"
        min="30"
        max="70"
        step="1"
        class="min-w-0 flex-1 accent-sky-600"
      />
      <input
        v-model.number="settings.angle_z"
        type="number"
        min="30"
        max="70"
        step="1"
        class="w-14 flex-none rounded-md border border-slate-300 bg-white px-2 py-1 text-right text-xs tabular-nums focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200"
      />
    </div>

    <div class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300">
      <span class="w-14 flex-none">{{ t('rotate.angleX') }}</span>
      <input
        v-model.number="settings.angle_x"
        type="range"
        min="30"
        max="70"
        step="1"
        class="min-w-0 flex-1 accent-sky-600"
      />
      <input
        v-model.number="settings.angle_x"
        type="number"
        min="30"
        max="70"
        step="1"
        class="w-14 flex-none rounded-md border border-slate-300 bg-white px-2 py-1 text-right text-xs tabular-nums focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200"
      />
    </div>
  </div>
</template>
