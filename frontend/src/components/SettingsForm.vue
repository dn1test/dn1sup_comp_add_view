<script setup>
// Форма настроек: редактирует объект draft родителя (одна и та же ссылка —
// реактивность работает напрямую). Сохранение уходит в Ruby через App.
defineProps({
  draft: { type: Object, required: true },
  dirty: { type: Boolean, default: false },
  busy: { type: Boolean, default: false }
})

defineEmits(['save', 'reset'])
</script>

<template>
  <section class="mx-4 mt-3 mb-4 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
    <div class="flex items-center justify-between">
      <h2 class="text-sm font-semibold text-slate-800">Настройки</h2>
      <span v-if="dirty" class="text-xs text-amber-600">● не сохранено</span>
      <span v-else class="text-xs text-emerald-600">✓ сохранено</span>
    </div>

    <label class="mt-3 flex items-center justify-between text-sm text-slate-700">
      <span>Создавать копию слева</span>
      <button
        type="button"
        role="switch"
        :aria-checked="draft.make_copy"
        class="relative inline-flex h-5 w-9 flex-none items-center rounded-full transition"
        :class="draft.make_copy ? 'bg-sky-600' : 'bg-slate-300'"
        @click="draft.make_copy = !draft.make_copy"
      >
        <span
          class="inline-block h-4 w-4 transform rounded-full bg-white shadow transition"
          :class="draft.make_copy ? 'translate-x-4' : 'translate-x-1'"
        ></span>
      </button>
    </label>

    <div class="mt-3">
      <div class="flex items-center justify-between text-sm text-slate-700">
        <span>Угол Z (сначала)</span>
        <input
          v-model.number="draft.angle_z"
          type="number"
          min="-360"
          max="360"
          step="1"
          class="w-16 rounded-md border border-slate-300 px-2 py-1 text-right text-xs tabular-nums focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
        />
      </div>
      <input v-model.number="draft.angle_z" type="range" min="0" max="180" step="5" class="mt-1 w-full accent-sky-600" />
    </div>

    <div class="mt-2">
      <div class="flex items-center justify-between text-sm text-slate-700">
        <span>Угол X (затем)</span>
        <input
          v-model.number="draft.angle_x"
          type="number"
          min="-360"
          max="360"
          step="1"
          class="w-16 rounded-md border border-slate-300 px-2 py-1 text-right text-xs tabular-nums focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
        />
      </div>
      <input v-model.number="draft.angle_x" type="range" min="0" max="180" step="5" class="mt-1 w-full accent-sky-600" />
    </div>

    <div class="mt-3 flex items-center justify-between text-sm text-slate-700">
      <span>Вид сбоку</span>
      <div class="flex rounded-lg border border-slate-200 p-0.5">
        <button
          v-for="s in ['Справа', 'Слева']"
          :key="s"
          type="button"
          class="rounded-md px-3 py-1 text-xs font-medium transition"
          :class="draft.side_view === s ? 'bg-sky-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-50'"
          @click="draft.side_view = s"
        >
          {{ s }}
        </button>
      </div>
    </div>

    <label class="mt-3 block text-sm text-slate-700">
      <span>Отступ проекций</span>
      <input
        v-model="draft.offset"
        type="text"
        placeholder="20% или 150"
        class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
      />
      <span class="mt-1 block text-xs text-slate-400">Проценты от габарита («20%») или миллиметры («150»)</span>
    </label>

    <div class="mt-4 flex gap-2">
      <button
        type="button"
        class="flex-1 rounded-lg bg-sky-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-sky-700 active:bg-sky-800 disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="busy"
        @click="$emit('save')"
      >
        {{ busy ? 'Сохранение…' : 'Сохранить настройки' }}
      </button>
      <button
        type="button"
        class="rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-600 transition hover:bg-slate-50"
        @click="$emit('reset')"
      >
        Сбросить
      </button>
    </div>
  </section>
</template>
