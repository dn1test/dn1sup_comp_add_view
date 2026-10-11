<script setup>
import { computed } from 'vue'

// Схема чертёжной раскладки проекций: исходный объект, копия «вид сверху»
// над ним (+Z) и копия «вид сбоку» справа или слева (+X / −X) с отступом.
const props = defineProps({
  sideView: { type: String, default: 'Справа' },
  offset: { type: String, default: '20%' }
})

const isLeft = computed(() => props.sideView === 'Слева')

const offsetLabel = computed(() => {
  const s = String(props.offset || '').trim()
  return s.includes('%') ? s : `${s} мм`
})
</script>

<template>
  <div>
    <svg viewBox="0 0 260 150" class="block w-full" role="img" aria-label="Схема раскладки проекций">
      <defs>
        <marker id="views-a" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="6" markerHeight="6" orient="auto">
          <path d="M0 0 L8 4 L0 8 Z" fill="#64748b" />
        </marker>
        <marker id="views-r" viewBox="0 0 8 8" refX="1" refY="4" markerWidth="6" markerHeight="6" orient="auto">
          <path d="M8 0 L0 4 L8 8 Z" fill="#64748b" />
        </marker>
      </defs>

      <text x="8" y="14" class="fill-slate-400" font-size="9">раскладка проекций (план)</text>

      <!-- копия «вид сверху» (поворот X +90°), размещается над объектом -->
      <rect x="100" y="15" width="60" height="40" rx="3" fill="#fef3c7" stroke="#d97706" stroke-width="1.4" stroke-dasharray="4 3" />
      <text x="130" y="38" text-anchor="middle" class="fill-amber-700" font-size="9">вид сверху</text>

      <!-- вертикальный отступ -->
      <line x1="130" y1="59" x2="130" y2="81" stroke="#64748b" stroke-width="1.2" marker-start="url(#views-r)" marker-end="url(#views-a)" />
      <text x="124" y="73" text-anchor="end" class="fill-slate-500" font-size="8">{{ offsetLabel }}</text>

      <!-- исходный объект -->
      <rect x="100" y="85" width="60" height="50" rx="3" fill="#e0f2fe" stroke="#0284c7" stroke-width="1.5" />
      <text x="130" y="113" text-anchor="middle" class="fill-sky-800" font-size="9">исходный</text>

      <!-- горизонтальный отступ -->
      <template v-if="!isLeft">
        <line x1="164" y1="110" x2="186" y2="110" stroke="#64748b" stroke-width="1.2" marker-start="url(#views-r)" marker-end="url(#views-a)" />
        <text x="175" y="104" text-anchor="middle" class="fill-slate-500" font-size="8">{{ offsetLabel }}</text>
      </template>
      <template v-else>
        <line x1="74" y1="110" x2="96" y2="110" stroke="#64748b" stroke-width="1.2" marker-start="url(#views-r)" marker-end="url(#views-a)" />
        <text x="85" y="104" text-anchor="middle" class="fill-slate-500" font-size="8">{{ offsetLabel }}</text>
      </template>

      <!-- копия «вид сбоку» (поворот Z −90° справа / +90° слева) -->
      <g v-if="!isLeft">
        <rect x="190" y="85" width="50" height="50" rx="3" fill="#fef3c7" stroke="#d97706" stroke-width="1.4" stroke-dasharray="4 3" />
        <text x="215" y="113" text-anchor="middle" class="fill-amber-700" font-size="9">вид сбоку</text>
      </g>
      <g v-else>
        <rect x="20" y="85" width="50" height="50" rx="3" fill="#fef3c7" stroke="#d97706" stroke-width="1.4" stroke-dasharray="4 3" />
        <text x="45" y="113" text-anchor="middle" class="fill-amber-700" font-size="9">вид сбоку</text>
      </g>
    </svg>

    <div class="flex flex-wrap items-center gap-1.5 px-3 pb-2">
      <span class="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-700">
        сбоку: {{ isLeft ? 'слева (−X)' : 'справа (+X)' }}
      </span>
      <span class="rounded bg-slate-100 px-1.5 py-0.5 text-[10px] font-medium text-slate-600">отступ: {{ offsetLabel }}</span>
    </div>
  </div>
</template>
