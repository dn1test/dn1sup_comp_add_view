<script setup>
// Блок операции: заголовок, параметры (слот #params) и зона действия.
// По умолчанию в зоне действия — кнопка (buttonLabel); слотом #action её можно
// заменить (например, галочкой выбора операции: общая кнопка «Применить» одна
// на все блоки — см. App.vue). Параметры применяются сразу (автосохранение).
import { t } from '../i18n/index.js'

defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  buttonLabel: { type: String, default: '' },
  busy: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false }
})

defineEmits(['run'])
</script>

<template>
  <section class="mx-4 mt-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900">
    <slot name="title">
      <h2 class="text-sm font-semibold text-slate-800 dark:text-slate-100">{{ title }}</h2>
    </slot>
    <p v-if="description" class="mt-0.5 text-xs leading-relaxed text-slate-500 dark:text-slate-400">{{ description }}</p>

    <div class="mt-3">
      <slot name="params" />
    </div>

    <div v-if="buttonLabel || $slots.action" class="mt-3">
      <slot name="action">
        <button
          v-if="buttonLabel"
          type="button"
          class="w-full rounded-lg bg-sky-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-sky-700 active:bg-sky-800 disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="busy || disabled"
          @click="$emit('run')"
        >
          {{ busy ? t('apply.running') : buttonLabel }}
        </button>
      </slot>
    </div>
  </section>
</template>
