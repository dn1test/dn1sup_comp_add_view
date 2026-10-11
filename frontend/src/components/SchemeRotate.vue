<script setup>
import { computed } from 'vue'

// Схема вида сверху (план): исходный объект, копия слева на ширину объекта
// и поворот вокруг точки вставки сначала по Z (в плане), затем по X (из плана).
// Ось X модели — вправо, ось Y — вверх; положительный поворот по Z виден
// против часовой стрелки, в SVG это rotate(-angle).
const props = defineProps({
  angleZ: { type: Number, default: 35 },
  angleX: { type: Number, default: 35 },
  makeCopy: { type: Boolean, default: true }
})

const ORIGIN = { x: 200, y: 85 } // точка вставки исходного объекта
const WIDTH = 60 // габаритная ширина исходного объекта на схеме

// точка на окружности; deg — угол ПО ЧАСОВОЙ на экране (ось Y SVG вниз)
function polar(r, deg) {
  const rad = (deg * Math.PI) / 180
  return { x: ORIGIN.x + r * Math.cos(rad), y: ORIGIN.y - r * Math.sin(rad) }
}

const zNorm = computed(() => ((props.angleZ % 360) + 360) % 360)

// дуга поворота вокруг точки вставки: от направления «влево» против часовой
// на экране на угол Z (против часовой = 180° + Z в параметризации polar)
const arcPath = computed(() => {
  if (zNorm.value < 3 || zNorm.value > 357) return ''
  const r = 36
  const start = polar(r, 180)
  const end = polar(r, 180 + zNorm.value)
  const large = zNorm.value > 180 ? 1 : 0
  return `M ${start.x.toFixed(1)} ${start.y.toFixed(1)} A ${r} ${r} 0 ${large} 0 ${end.x.toFixed(1)} ${end.y.toFixed(1)}`
})

// копия: поворот вокруг точки вставки, затем сдвиг влево на ширину
const copyTransform = computed(
  () => `translate(-${WIDTH} 0) rotate(${-props.angleZ} ${ORIGIN.x} ${ORIGIN.y})`
)

const originalTransform = computed(() =>
  props.makeCopy ? '' : `rotate(${-props.angleZ} ${ORIGIN.x} ${ORIGIN.y})`
)
</script>

<template>
  <div>
    <svg viewBox="0 0 260 122" class="block w-full" role="img" aria-label="Схема поворота">
      <defs>
        <marker id="rot-arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path d="M0 0 L8 4 L0 8 Z" fill="#64748b" />
        </marker>
      </defs>

      <text x="8" y="14" class="fill-slate-400" font-size="9">вид сверху (план)</text>
      <text x="252" y="14" text-anchor="end" class="fill-slate-400" font-size="9">затем ↻ X</text>

      <!-- дуга поворота по Z вокруг точки вставки -->
      <path
        v-if="arcPath"
        :d="arcPath"
        fill="none"
        stroke="#64748b"
        stroke-width="1.4"
        stroke-dasharray="3 3"
        marker-end="url(#rot-arrow)"
      />

      <!-- копия: сдвиг влево и поворот по Z -->
      <g v-if="makeCopy" :transform="copyTransform">
        <rect
          x="140" y="45" :width="WIDTH" height="40" rx="3"
          fill="#fef3c7" stroke="#d97706" stroke-width="1.4" stroke-dasharray="4 3"
        />
        <circle :cx="ORIGIN.x" :cy="ORIGIN.y" r="2.5" fill="#d97706" />
      </g>

      <!-- исходный объект (или объект на месте при повороте без копии) -->
      <g :transform="originalTransform">
        <rect x="140" y="45" :width="WIDTH" height="40" rx="3" fill="#e0f2fe" stroke="#0284c7" stroke-width="1.5" />
        <text x="170" y="68" text-anchor="middle" class="fill-sky-800" font-size="9">исходный</text>
        <circle :cx="ORIGIN.x" :cy="ORIGIN.y" r="2.5" fill="#0284c7" />
      </g>

      <!-- сдвиг влево на ширину объекта -->
      <g v-if="makeCopy">
        <line x1="168" y1="112" x2="112" y2="112" stroke="#64748b" stroke-width="1.2" marker-end="url(#rot-arrow)" />
        <text x="140" y="121" text-anchor="middle" class="fill-slate-400" font-size="8">сдвиг на ширину</text>
      </g>
    </svg>

    <div class="flex flex-wrap items-center gap-1.5 px-3 pb-2">
      <span class="rounded bg-sky-100 px-1.5 py-0.5 text-[10px] font-medium text-sky-700">Z: {{ angleZ }}°</span>
      <span class="rounded bg-indigo-100 px-1.5 py-0.5 text-[10px] font-medium text-indigo-700">X: {{ angleX }}°</span>
      <span class="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-700">
        {{ makeCopy ? 'копия слева' : 'поворот на месте' }}
      </span>
    </div>
  </div>
</template>
