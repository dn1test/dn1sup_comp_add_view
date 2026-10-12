<script setup>
// Параметры блока «Проекции»: мутируют объект settings родителя по ссылке.
defineProps({
  settings: { type: Object, required: true }
})

const SIDES = ['Справа', 'Слева']
</script>

<template>
  <div class="space-y-2.5">
    <div class="flex items-center justify-between text-sm text-slate-700">
      <span>Вид сбоку</span>
      <div class="flex rounded-lg border border-slate-200 p-0.5">
        <button
          v-for="s in SIDES"
          :key="s"
          type="button"
          class="rounded-md px-3 py-1 text-xs font-medium transition"
          :class="settings.side_view === s ? 'bg-sky-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-50'"
          @click="settings.side_view = s"
        >
          {{ s }}
        </button>
      </div>
    </div>

    <label class="flex items-center gap-2 text-sm text-slate-700">
      <span class="w-14 flex-none">Отступ</span>
      <input
        v-model="settings.offset"
        type="text"
        placeholder="20% или 150"
        class="min-w-0 flex-1 rounded-md border border-slate-300 px-2 py-1.5 text-sm focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
      />
    </label>
  </div>
</template>
