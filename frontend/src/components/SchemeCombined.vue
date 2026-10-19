<script setup>
import { computed } from 'vue'

// Единая картина раскладки: исходный объект в центре и три копии вокруг него —
// «вид сверху» над ним (поворот X +90°, отступ по Z), «вид сбоку» справа
// (поворот Z ∓90°, направление взгляда по переключателю, отступ по X) и
// повёрнутая копия слева (сдвиг на ширину плюс отступ, поворот по Z — тумблер
// «+180°» добавляет 180°, затем доворот по X).
// Повёрнутая копия нарисована кубом в изометрии: поворот по Z — вокруг точки
// вставки (передний левый нижний угол), наклон по X — вокруг модельной оси X;
// порядок как в rotator.rb (сначала Z, затем X), после наклона низ возвращается
// на уровень пола (как dz в rotator.rb). Исходный объект — плоский квадрат,
// всегда стоит прямо; в режиме «поворота на месте» итоговая поза — призраком
// на том же месте. У каждой модели — триада осей X/Y/Z вдоль её рёбер.
// Проекции «вид сверху»/«вид сбоку» остаются плоскими — это виды, а не объём.
const props = defineProps({
  angleZ: { type: Number, default: 35 },
  angleX: { type: Number, default: 35 },
  makeCopy: { type: Boolean, default: true },
  sideView: { type: String, default: 'Справа' },
  offsetPercent: { type: Number, default: 20 },
  rot180: { type: Boolean, default: false }
})

// --- раскладка схемы ---
// точка вставки — передний левый нижний угол объекта (как у компонента);
// вращение на схеме выполняется вокруг неё
const ORIGIN = { x: 130, y: 117 }
const SHIFT = 84 // сдвиг копии влево: ширина объекта + зазор (реальный отступ — в % габарита)
const COPY_ORIGIN = { x: ORIGIN.x - SHIFT, y: ORIGIN.y } // точка вставки копии

// --- мини-3D: параллелепипед в изометрической проекции ---
const SCALE = 0.7 // масштаб проекции, px на единицу схемы
// камера спереди-справа-сверху (октант +X, −Y, +Z); базис подобран так, что
// поворот по Z виден на экране против часовой — как в SketchUp (вид сверху)
const VIEW = { x: 0.41, y: -0.71, z: 0.58 } // направление к камере (единичное)
const LIGHT = { x: -0.7, y: -0.3, z: 1 } // свет сверху-слева (не нормализован, пороги под него)
const BOX = { w: 48, d: 48, h: 48 } // куб — все стороны равны
const PALETTE_COPY = { tones: ['#fef9c3', '#fde68a', '#fcd34d', '#fbbf24'], stroke: '#d97706' } // янтарная — копия
const PALETTE_ORIG = { tones: ['#f0f9ff', '#e0f2fe', '#bae6fd', '#7dd3fc'], stroke: '#0284c7' } // небесная — исходный

// модель: X вправо, Y вглубь плана, Z вверх; на экране X — вправо-вниз,
// Y — вправо-вверх (вглубь), Z — вверх
function project(p) {
  return {
    x: (0.866 * p.x + 0.5 * p.y) * SCALE,
    y: (0.289 * p.x - 0.5 * p.y - 0.817 * p.z) * SCALE
  }
}

function rotZ(p, deg) {
  const rad = (deg * Math.PI) / 180
  const c = Math.cos(rad)
  const s = Math.sin(rad)
  return { x: p.x * c - p.y * s, y: p.x * s + p.y * c, z: p.z }
}

function rotX(p, deg) {
  const rad = (deg * Math.PI) / 180
  const c = Math.cos(rad)
  const s = Math.sin(rad)
  return { x: p.x, y: p.y * c - p.z * s, z: p.y * s + p.z * c }
}

// 8 вершин бокса от точки вставки (передний левый нижний угол = модельный
// ноль; базовые индексы: 0..3 — низ, 4..7 — верх)
const CORNERS = [
  { x: 0, y: 0, z: 0 }, { x: BOX.w, y: 0, z: 0 },
  { x: 0, y: BOX.d, z: 0 }, { x: BOX.w, y: BOX.d, z: 0 },
  { x: 0, y: 0, z: BOX.h }, { x: BOX.w, y: 0, z: BOX.h },
  { x: 0, y: BOX.d, z: BOX.h }, { x: BOX.w, y: BOX.d, z: BOX.h }
]

// 6 граней с внешними нормалями (единичными — вращения длину не меняют)
const FACES = [
  { idx: [0, 1, 5, 4], n: { x: 0, y: -1, z: 0 } }, // перед (Y−)
  { idx: [2, 6, 7, 3], n: { x: 0, y: 1, z: 0 } }, // зад (Y+)
  { idx: [0, 4, 6, 2], n: { x: -1, y: 0, z: 0 } }, // лево (X−)
  { idx: [1, 3, 7, 5], n: { x: 1, y: 0, z: 0 } }, // право (X+)
  { idx: [4, 5, 7, 6], n: { x: 0, y: 0, z: 1 } }, // верх
  { idx: [0, 2, 3, 1], n: { x: 0, y: 0, z: -1 } } // низ
]

// грани, невидимые с камеры, — тонким пунктиром (как каркас-призрак в preview.rb)
function boxView({ rotZdeg, tiltXdeg, origin, palette }) {
  let pts = CORNERS.map((c) => rotX(rotZ(c, rotZdeg), tiltXdeg))
  const lift = -Math.min(...pts.map((p) => p.z))
  pts = pts.map((p) => ({ ...p, z: p.z + lift }))
  const screen = pts.map((p) => {
    const s = project(p)
    return { x: origin.x + s.x, y: origin.y + s.y }
  })
  const toPoints = (idx) => idx.map((i) => `${screen[i].x.toFixed(1)},${screen[i].y.toFixed(1)}`).join(' ')
  const toPath = (idx) => `M ${idx.map((i) => `${screen[i].x.toFixed(1)},${screen[i].y.toFixed(1)}`).join(' L ')} Z`
  const faces = []
  const hidden = []
  for (const f of FACES) {
    const rn = rotX(rotZ(f.n, rotZdeg), tiltXdeg)
    const toward = rn.x * VIEW.x + rn.y * VIEW.y + rn.z * VIEW.z
    const l = rn.x * LIGHT.x + rn.y * LIGHT.y + rn.z * LIGHT.z
    const item = { pts: toPoints(f.idx), d: toPath(f.idx), fill: palette.tones[l >= 0.75 ? 0 : l >= 0.45 ? 1 : l >= 0 ? 2 : 3] }
    if (toward > 0) faces.push(item)
    else hidden.push(item)
  }
  const dot = project({ x: 0, y: 0, z: lift })
  return {
    faces,
    hidden,
    dot: { x: origin.x + dot.x, y: origin.y + dot.y },
    // направления локальных осей объекта после его поворотов (Z, затем X):
    // рёбра куба и есть эти оси
    axes: {
      x: rotX(rotZ({ x: 1, y: 0, z: 0 }, rotZdeg), tiltXdeg),
      y: rotX(rotZ({ x: 0, y: 1, z: 0 }, rotZdeg), tiltXdeg),
      z: rotX(rotZ({ x: 0, y: 0, z: 1 }, rotZdeg), tiltXdeg)
    }
  }
}

// эффективный угол копии по Z: слайдер 30–70° плюс тумблер «+180°»
const effZ = computed(() => (((props.angleZ + (props.rot180 ? 180 : 0)) % 360) + 360) % 360)

// дуга поворота по Z «по полу» вокруг точки вставки: от направления «влево»
// (−X на плане) против часовой на угол Z; полилиния из спроецированных точек
function floorArcPath(center, sweepDeg) {
  if (sweepDeg < 3 || sweepDeg > 357) return ''
  const radius = 44
  const steps = Math.max(2, Math.ceil(sweepDeg / 6))
  const pts = []
  for (let i = 0; i <= steps; i++) {
    const a = ((180 + (sweepDeg * i) / steps) * Math.PI) / 180
    const p = project({ x: radius * Math.cos(a), y: radius * Math.sin(a), z: 0 })
    pts.push(`${(center.x + p.x).toFixed(1)},${(center.y + p.y).toFixed(1)}`)
  }
  return `M ${pts.join(' L ')}`
}

const copyArc = computed(() => (props.makeCopy ? floorArcPath(COPY_ORIGIN, effZ.value) : ''))
const inPlaceArc = computed(() => (props.makeCopy ? '' : floorArcPath(ORIGIN, effZ.value)))

// объёмный параллелепипед — только у повёрнутой копии (итоговая поза:
// поворот Z + наклон X); исходный объект — плоский прямоугольник, всегда
// стоит прямо; в режиме «поворота на месте» итоговая поза показывается
// призраком на том же месте
const copyBox = computed(() =>
  boxView({ rotZdeg: effZ.value, tiltXdeg: props.angleX, origin: COPY_ORIGIN, palette: PALETTE_COPY })
)
const inPlaceGhost = computed(() =>
  boxView({ rotZdeg: effZ.value, tiltXdeg: props.angleX, origin: ORIGIN, palette: PALETTE_ORIG })
)

// триады осей X/Y/Z у каждой модели: направлены вдоль рёбер объекта, то есть
// поворачиваются вместе с ним; цвета — как оси в SketchUp
const AXIS_LEN = 24
function norm2(v) {
  const l = Math.hypot(v.x, v.y) || 1
  return { x: v.x / l, y: v.y / l }
}

// локальные оси куба -> экранные направления (проекция повёрнутых векторов)
function boxAxisDirs(axes) {
  return { x: norm2(project(axes.x)), y: norm2(project(axes.y)), z: norm2(project(axes.z)) }
}

function triadArrows(anchor, dirs, len = AXIS_LEN) {
  const mk = (d, label, color, marker) => ({
    x2: anchor.x + d.x * len,
    y2: anchor.y + d.y * len,
    lx: anchor.x + d.x * (len + 8) + 1,
    ly: anchor.y + d.y * (len + 8) + 3,
    label, color, marker
  })
  return [
    mk(dirs.x, 'X', '#dc2626', 'sch-ax-x'),
    mk(dirs.y, 'Y', '#16a34a', 'sch-ax-y'),
    mk(dirs.z, 'Z', '#2563eb', 'sch-ax-z')
  ]
}

// L-оси плоских видов (исходный, «вид сверху», «вид сбоку»): полый кружок в
// точке вставки + две цветные линии по осям вида с буквами. Оси в плоскости
// каждого вида: исходный — X/Z, «вид сверху» — X/Y, «вид сбоку» — Y/Z.
// У «вида сбоку» уголок зеркален (Z ∓90°: точка справа, линия влево)
const AXIS_COLORS = { X: '#dc2626', Y: '#16a34a', Z: '#2563eb' }

const flatAxes = computed(() => {
  const mirror = props.sideView === 'Справа'
  // буквы — рядом с линиями, как на чертеже: у горизонтали — снизу ближе к
  // концу линии, у вертикали — с внешней стороны (от детали), ближе к верху
  const mk = (key, anchor, hx, hy, hLabel, vx, vy, vLabel) => {
    const hs = hx >= anchor.x ? 1 : -1
    return {
      key, anchor,
      hLine: {
        x2: hx, y2: hy, label: hLabel, color: AXIS_COLORS[hLabel],
        lx: anchor.x + hs * 10, ly: anchor.y + 9
      },
      vLine: {
        x2: vx, y2: vy, label: vLabel, color: AXIS_COLORS[vLabel],
        lx: vx + (hs > 0 ? -9 : 4), ly: anchor.y - 7
      }
    }
  }
  const list = [
    mk('orig', { x: 103, y: 131 }, 119, 131, 'X', 103, 115, 'Z'),
    mk('top', { x: 97, y: 52 }, 113, 52, 'X', 97, 36, 'Y')
  ]
  list.push(
    mirror
      ? mk('side', { x: 243, y: 131 }, 227, 131, 'Y', 243, 115, 'Z')
      : mk('side', { x: 187, y: 131 }, 203, 131, 'Y', 187, 115, 'Z')
  )
  return list
})

const allTriads = computed(() => {
  const list = []
  const box = props.makeCopy ? copyBox.value : inPlaceGhost.value
  list.push({
    key: props.makeCopy ? 'copy' : 'ghost',
    anchor: box.dot,
    arrows: triadArrows(box.dot, boxAxisDirs(box.axes)),
    opacity: props.makeCopy ? 1 : 0.75,
    dot: props.makeCopy ? '#d97706' : '#0284c7'
  })
  return list
})
</script>

<template>
  <div>
    <svg viewBox="-14 0 274 164" class="block w-full bg-slate-50/60" role="img" aria-label="Схема поворота и проекций">
      <defs>
        <marker id="sch-arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path d="M0 0 L8 4 L0 8 Z" fill="#64748b" />
        </marker>
        <marker id="sch-ax-x" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="5" markerHeight="5" orient="auto-start-reverse">
          <path d="M0 0 L8 4 L0 8 Z" fill="#dc2626" />
        </marker>
        <marker id="sch-ax-y" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="5" markerHeight="5" orient="auto-start-reverse">
          <path d="M0 0 L8 4 L0 8 Z" fill="#16a34a" />
        </marker>
        <marker id="sch-ax-z" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="5" markerHeight="5" orient="auto-start-reverse">
          <path d="M0 0 L8 4 L0 8 Z" fill="#2563eb" />
        </marker>
      </defs>

      <text x="8" y="14" class="fill-slate-400" font-size="9">вид сверху (план)</text>
      <text x="252" y="14" text-anchor="end" class="fill-slate-400" font-size="9">затем ↻ X</text>

      <!-- копия «вид сверху»: над исходным объектом с вертикальным отступом -->
      <rect x="100" y="16" width="60" height="32" rx="3" fill="#fef3c7" stroke="#d97706" stroke-width="1.4" stroke-dasharray="4 3" />
      <text x="130" y="35" text-anchor="middle" class="fill-amber-700" font-size="9">вид сверху</text>
      <line x1="130" y1="52" x2="130" y2="68" stroke="#64748b" stroke-width="1.2" marker-start="url(#sch-arrow)" marker-end="url(#sch-arrow)" />
      <text x="136" y="63" class="fill-slate-500" font-size="8">{{ offsetPercent }}%</text>

      <!-- повёрнутая копия: объёмный параллелепипед, сдвиг влево + поворот Z, наклон X -->
      <g v-if="makeCopy">
        <path v-for="(h, i) in copyBox.hidden" :key="`ch${i}`" :d="h.d" fill="none" :stroke="PALETTE_COPY.stroke" stroke-width="0.7" stroke-dasharray="2 2" opacity="0.35" />
        <polygon v-for="(f, i) in copyBox.faces" :key="`cf${i}`" :points="f.pts" :fill="f.fill" :stroke="PALETTE_COPY.stroke" stroke-width="1.1" stroke-linejoin="round" />
      </g>

      <!-- исходный объект: плоский квадрат (куб), всегда стоит прямо;
           точка вставки — передний левый нижний угол -->
      <g>
        <rect x="106" y="80" width="48" height="48" rx="3" fill="#e0f2fe" stroke="#0284c7" stroke-width="1.5" />
        <text x="130" y="96" text-anchor="middle" class="fill-sky-800" font-size="9">исходный</text>
      </g>

      <!-- «поворот на месте»: итоговая поза призраком на том же месте -->
      <g v-if="!makeCopy" fill-opacity="0.45" stroke-dasharray="3 2">
        <polygon v-for="(f, i) in inPlaceGhost.faces" :key="`gf${i}`" :points="f.pts" :fill="f.fill" :stroke="PALETTE_ORIG.stroke" stroke-width="1.1" stroke-linejoin="round" />
      </g>

      <!-- дуга поворота по Z «по полу» вокруг точки вставки (поверх кубов —
           как стрелка-аннотация: передняя часть круга ближе объекта) -->
      <path
        v-if="copyArc || inPlaceArc"
        :d="copyArc || inPlaceArc"
        fill="none"
        stroke="#64748b"
        stroke-width="1.4"
        stroke-dasharray="3 3"
        marker-end="url(#sch-arrow)"
      />

      <!-- оси X/Y/Z объёмных моделей: направлены вдоль рёбер, поворачиваются
           вместе с объектом; цвета как оси в SketchUp -->
      <g v-for="t in allTriads" :key="t.key" :opacity="t.opacity" font-size="8">
        <circle :cx="t.anchor.x" :cy="t.anchor.y" r="2.5" :fill="t.dot" />
        <line
          v-for="a in t.arrows"
          :key="a.marker"
          :x1="t.anchor.x" :y1="t.anchor.y" :x2="a.x2" :y2="a.y2"
          :stroke="a.color" stroke-width="1.4" :marker-end="`url(#${a.marker})`"
        />
        <text v-for="a in t.arrows" :key="a.marker + 'l'" :x="a.lx" :y="a.ly" :fill="a.color">{{ a.label }}</text>
      </g>

      <!-- L-оси плоских видов: кружок в точке вставки + цветные линии по осям
           вида с буквами; у «вида сбоку» зеркально -->
      <g v-for="l in flatAxes" :key="l.key">
        <circle :cx="l.anchor.x" :cy="l.anchor.y" r="3" fill="#fff" stroke="#475569" stroke-width="1.1" />
        <line :x1="l.anchor.x" :y1="l.anchor.y" :x2="l.hLine.x2" :y2="l.hLine.y2" :stroke="l.hLine.color" stroke-width="1.3" />
        <line :x1="l.anchor.x" :y1="l.anchor.y" :x2="l.vLine.x2" :y2="l.vLine.y2" :stroke="l.vLine.color" stroke-width="1.3" />
        <text :x="l.hLine.lx" :y="l.hLine.ly" :fill="l.hLine.color" font-size="8">{{ l.hLine.label }}</text>
        <text :x="l.vLine.lx" :y="l.vLine.ly" :fill="l.vLine.color" font-size="8">{{ l.vLine.label }}</text>
      </g>

      <!-- копия «вид сбоку»: всегда справа, направление взгляда по переключателю -->
      <line x1="164" y1="103" x2="186" y2="103" stroke="#64748b" stroke-width="1.2" marker-start="url(#sch-arrow)" marker-end="url(#sch-arrow)" />
      <text x="175" y="97" text-anchor="middle" class="fill-slate-500" font-size="8">{{ offsetPercent }}%</text>
      <rect x="190" y="78" width="50" height="50" rx="3" fill="#fef3c7" stroke="#d97706" stroke-width="1.4" stroke-dasharray="4 3" />
      <text x="215" y="106" text-anchor="middle" class="fill-amber-700" font-size="9">вид сбоку</text>
      <text x="215" y="118" text-anchor="middle" class="fill-amber-700/70" font-size="8">вид {{ sideView === 'Слева' ? 'слева' : 'справа' }}</text>

      <!-- сдвиг копии влево: ширина объекта плюс отступ -->
      <g v-if="makeCopy">
        <line x1="100" y1="140" x2="24" y2="140" stroke="#64748b" stroke-width="1.2" marker-end="url(#sch-arrow)" />
        <text x="62" y="152" text-anchor="middle" class="fill-slate-400" font-size="8">сдвиг на ширину + {{ offsetPercent }}%</text>
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
