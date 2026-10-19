<script setup>
// Блок операции: заголовок, параметры (слот #params) и кнопка действия.
// Схема операций — одна общая в App.vue (SchemeCombined). Параметры применяются
// сразу (автосохранение в App.vue), кнопка выполняет операцию над выделением.
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  buttonLabel: { type: String, required: true },
  busy: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false }
})

defineEmits(['run'])
</script>

<template>
  <section class="mx-4 mt-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
    <h2 class="text-sm font-semibold text-slate-800">{{ title }}</h2>
    <p v-if="description" class="mt-0.5 text-xs leading-relaxed text-slate-500">{{ description }}</p>

    <div class="mt-3">
      <slot name="params" />
    </div>

    <button
      type="button"
      class="mt-3 w-full rounded-lg bg-sky-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-sky-700 active:bg-sky-800 disabled:cursor-not-allowed disabled:opacity-50"
      :disabled="busy || disabled"
      @click="$emit('run')"
    >
      {{ busy ? 'Выполняется…' : buttonLabel }}
    </button>
  </section>
</template>
