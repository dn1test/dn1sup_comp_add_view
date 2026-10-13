// Мост к Ruby-колбэкам HtmlDialog (dialog.rb модуля Panel).
//
// В SU2026 (Qt WebEngine) у JS-моста НЕТ sketchup.callRuby — колбэки,
// зарегистрированные add_action_callback, вызываются напрямую:
//     sketchup.<имя_колбэка>(arg1, arg2, ...)
// Возврата значений тоже нет: Ruby отвечает пушем window.__dn1Event(evt)
// через execute_script. Для совместимости с CEF-версиями (SU2020.1+)
// сохранён фолбэк на callRuby/call_ruby. Вне SketchUp (предпросмотр HTML
// в браузере) мост отвечает мок-данными.

const MOCK_VERSION = '0.6.1'

const mockState = {
  angle_z: 35,
  angle_x: 35,
  make_copy: true,
  side_view: 'Справа',
  offset: '20%',
  selection: { total: 3, targets: 1 }
}

const pending = new Map()
const handlers = new Map()
let seq = 0

function sketchupBridge() {
  return typeof window !== 'undefined' ? window.sketchup : undefined
}

// Прямой вызов колбэка с любым из трёх известных API-стилей моста
function invoke(action, args) {
  const su = sketchupBridge()
  if (!su) return false
  try {
    if (typeof su[action] === 'function') {
      su[action](...args)
      return true
    }
    if (typeof su.callRuby === 'function') {
      su.callRuby(action, ...args)
      return true
    }
    if (typeof su.call_ruby === 'function') {
      su.call_ruby(action, ...args)
      return true
    }
  } catch {
    /* мост недоступен — вызов уйдёт в мок */
  }
  return false
}

// Точка приёма событий из Ruby (dialog.rb: Panel.push_event). Событие с id
// резолвит ожидающий callRuby-промис; событие 'selection' уходит подписчикам.
window.__dn1Event = (evt) => {
  if (!evt || typeof evt !== 'object') return
  if (evt.id) {
    const waiter = pending.get(evt.id)
    if (waiter) {
      pending.delete(evt.id)
      clearTimeout(waiter.timer)
      waiter.resolve(evt.payload)
      return
    }
  }
  const list = handlers.get(evt.type)
  if (list) list.forEach((fn) => fn(evt.payload))
}

// Подписка на пуш-события Ruby (например, смена выделения)
export function onEvent(type, fn) {
  if (!handlers.has(type)) handlers.set(type, [])
  handlers.get(type).push(fn)
}

export function inSketchup() {
  const su = sketchupBridge()
  return !!su && (typeof su.callRuby === 'function' || Object.keys(su).length > 0)
}

// Вызов Ruby-колбэка: возвращает Promise с payload ответа (или null по таймауту)
export function callRuby(action, payload) {
  return new Promise((resolve) => {
    const id = `r${++seq}`
    const args = [id]
    if (payload !== undefined) args.push(JSON.stringify(payload))

    if (!invoke(action, args)) {
      resolve(mockCall(action, payload))
      return
    }
    pending.set(id, {
      resolve,
      timer: setTimeout(() => {
        if (pending.has(id)) {
          pending.delete(id)
          resolve(null)
        }
      }, 15000)
    })
  })
}

function mockCall(action, payload) {
  switch (action) {
    case 'settings_get':
      return { ...mockState, version: MOCK_VERSION }
    case 'settings_save': {
      const data = payload && typeof payload === 'object' ? payload : {}
      Object.assign(mockState, data)
      return { ...mockState, version: MOCK_VERSION }
    }
    case 'selection_info':
      return { ...mockState.selection }
    // Вне SketchUp живого 3D-предпросмотра нет — отвечаем состоянием панели
    case 'preview_update':
    case 'preview_views_update':
      return { preview: mockState.selection.targets > 0 }
    case 'preview_apply':
      return { action: 'rotate' }
    case 'preview_views_apply':
      return { action: 'views' }
    case 'preview_cancel':
      return null
    case 'check_update':
      return null
    default:
      return null
  }
}
