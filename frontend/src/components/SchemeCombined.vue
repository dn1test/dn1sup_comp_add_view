<script setup>
import { computed } from 'vue'

// Единая картина раскладки (вид сверху / план): исходный объект в центре и
// три копии вокруг него — «вид сверху» над ним (поворот X +90°, отступ по Z),
// «вид сбоку» справа (поворот Z ∓90°, направление взгляда по переключателю,
// отступ по X) и повёрнутая копия слева (сдвиг на ширину, поворот по Z —
// тумблер «+180°» добавляет 180°, затем доворот по X).
// Ось X модели — вправо, ось Y — вверх; положительный поворот по Z виден
// против часовой стрелки, в SVG это rotate(-angle).
const props = defineProps({
  angleZ: { type: Number, default: 35 },
  angleX: { type: Number, default: 35 },
  makeCopy: { type: Boolean, default: true },
  sideView: { type: String, default: 'Справа' },
  offsetPercent: { type: Number, default: 20 },
  rot180: { type: Boolean, default: false }
})

const ORIGIN = { x: 130, y: 103 } // точка вставки исходного объекта
const WIDTH = 60 // габаритная ширина исходного объекта на схеме
const COPY_ORIGIN = { x: ORIGIN.x - WIDTH, y: ORIGIN.y } // точка вставки копии

// точка на окружности; deg — угол ПО ЧАСОВОЙ на экране (ось Y SVG вниз)
function polar(center, r, deg) {
  const rad = (deg * Math.PI) / 180
  return { x: center.x + r * Math.cos(rad), y: center.y - r * Math.sin(rad) }
}

// эффективный угол копии по Z: слайдер 30–70° плюс тумблер «+180°»
const effZ = computed(() => (((props.angleZ + (props.rot180 ? 180 : 0)) % 360) + 360) % 360)

// дуга поворота вокруг точки вставки копии: от направления «влево» против
// часовой на экране на угол Z (против часовой = 180° + Z в параметризации polar)
const arcPath = computed(() => {
  if (effZ.value < 3 || effZ.value > 357) return ''
  const r = 34
  const start = polar(COPY_ORIGIN, r, 180)
  const end = polar(COPY_ORIGIN, r, 180 + effZ.value)
  const large = effZ.value > 180 ? 1 : 0
  return `M ${start.x.toFixed(1)} ${start.y.toFixed(1)} A ${r} ${r} 0 ${large} 0 ${end.x.toFixed(1)} ${end.y.toFixed(1)}`
})

// копия: сдвиг влево на ширину, затем поворот вокруг своей точки вставки
const copyTransform = computed(
  () => `translate(-${WIDTH} 0) rotate(${-effZ.value} ${ORIGIN.x} ${ORIGIN.y})`
)

const originalTransform = computed(() =>
  props.makeCopy ? '' : `rotate(${-effZ.value} ${ORIGIN.x} ${ORIGIN.y})`
)
</script>

<template>
  <div>
    <svg viewBox="0 0 260 160" class="block w-full bg-slate-50/60" role="img" aria-label="Схема поворота и проекций">
      <defs>
        <marker id="sch-arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path d="M0 0 L8 4 L0 8 Z" fill="#64748b" />
        </marker>
      </defs>

      <text x="8" y="14" class="fill-slate-400" font-size="9">вид сверху (план)</text>
      <text x="252" y="14" text-anchor="end" class="fill-slate-400" font-size="9">затем ↻ X</text>

      <!-- дуга поворота по Z вокруг точки вставки копии -->
      <path
        v-if="makeCopy && arcPath"
        :d="arcPath"
        fill="none"
        stroke="#64748b"
        stroke-width="1.4"
        stroke-dasharray="3 3"
        marker-end="url(#sch-arrow)"
      />

      <!-- копия «вид сверху»: над исходным объектом с вертикальным отступом -->
      <rect x="100" y="16" width="60" height="32" rx="3" fill="#fef3c7" stroke="#d97706" stroke-width="1.4" stroke-dasharray="4 3" />
      <text x="130" y="35" text-anchor="middle" class="fill-amber-700" font-size="9">вид сверху</text>
      <line x1="130" y1="52" x2="130" y2="74" stroke="#64748b" stroke-width="1.2" marker-start="url(#sch-arrow)" marker-end="url(#sch-arrow)" />
      <text x="124" y="66" text-anchor="end" class="fill-slate-500" font-size="8">{{ offsetPercent }}%</text>

      <!-- повёрнутая копия: сдвиг влево на ширину и поворот по Z (+180°) -->
      <g v-if="makeCopy" :transform="copyTransform">
        <rect
          x="100" y="78" :width="WIDTH" height="50" rx="3"
          fill="#fef3c7" stroke="#d97706" stroke-width="1.4" stroke-dasharray="4 3"
        />
        <circle :cx="ORIGIN.x" :cy="ORIGIN.y" r="2.5" fill="#d97706" />
      </g>

      <!-- исходный объект (или объект на месте при повороте без копии) -->
      <g :transform="originalTransform">
        <rect x="100" y="78" :width="WIDTH" height="50" rx="3" fill="#e0f2fe" stroke="#0284c7" stroke-width="1.5" />
        <text x="130" y="95" text-anchor="middle" class="fill-sky-800" font-size="9">исходный</text>
        <circle :cx="ORIGIN.x" :cy="ORIGIN.y" r="2.5" fill="#0284c7" />
      </g>

      <!-- копия «вид сбоку»: всегда справа, направление взгляда по переключателю -->
      <line x1="164" y1="103" x2="186" y2="103" stroke="#64748b" stroke-width="1.2" marker-start="url(#sch-arrow)" marker-end="url(#sch-arrow)" />
      <text x="175" y="97" text-anchor="middle" class="fill-slate-500" font-size="8">{{ offsetPercent }}%</text>
      <rect x="190" y="78" width="50" height="50" rx="3" fill="#fef3c7" stroke="#d97706" stroke-width="1.4" stroke-dasharray="4 3" />
      <text x="215" y="106" text-anchor="middle" class="fill-amber-700" font-size="9">вид сбоку</text>
      <text x="215" y="118" text-anchor="middle" class="fill-amber-700/70" font-size="8">вид {{ sideView === 'Слева' ? 'слева' : 'справа' }}</text>

      <!-- сдвиг копии влево на ширину объекта -->
      <g v-if="makeCopy">
        <line x1="100" y1="140" x2="72" y2="140" stroke="#64748b" stroke-width="1.2" marker-end="url(#sch-arrow)" />
        <text x="86" y="152" text-anchor="middle" class="fill-slate-400" font-size="8">сдвиг на ширину</text>
      </g>
    </svg>

    <div class="flex flex-wrap items-center gap-1.5 px-3 py-2">
      <span class="rounded bg-sky-100 px-1.5 py-0.5 text-[10px] font-medium text-sky-700">Z: {{ angleZ }}°</span>
      <span v-if="rot180" class="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-700">+180°</span>
      <span class="rounded bg-indigo-100 px-1.5 py-0.5 text-[10px] font-medium text-indigo-700">X: {{ angleX }}°</span>
      <span class="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-700">
        {{ makeCopy ? 'копия слева' : 'поворот на месте' }}
      </span>
      <span class="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-700">
        сбоку: вид {{ sideView === 'Слева' ? 'слева' : 'справа' }}
      </span>
      <span class="rounded bg-slate-100 px-1.5 py-0.5 text-[10px] font-medium text-slate-600">отступ: {{ offsetPercent }}%</span>
    </div>
  </div>
</template>
