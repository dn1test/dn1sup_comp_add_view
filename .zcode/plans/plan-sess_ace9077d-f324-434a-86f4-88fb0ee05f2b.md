# Единое меню DN1SUP для всех плагинов DN1SUP

## Цель
В меню «Расширения» остаётся **один** пункт `DN1SUP`, внутри него — вложенное подменю каждого из 5 приложений: Comp Add View, Time Project 2, AutoSelect Tag, Export PDF 2, Extension Store. Дубли исчезают.

## Механизм (единое соглашение)
Глобальная переменная **`$dn1sup_common_menu`** (конвенция уже задокументирована в time_project2): первый загрузившийся плагин создаёт `UI.menu('Extensions').add_submenu('DN1SUP')` и кэширует в глобал, остальные переиспользуют через `||=`. API SketchUp не умеет искать существующее подменю по имени, поэтому глобал — единственный способ совместного использования. `'Plugins'` и `'Extensions'` — одно и то же меню (подтверждено дока­ми), везде пишем `'Extensions'`.

## Правки по репозиториям

### 1. dn1sup_comp_add_view (этот репозиторий)
- `su_component_add_view/main.rb:29–36`: заменить `$dn1sup_menu` на `$dn1sup_common_menu` в строке 33, обновить комментарий (29–32). Структура DN1SUP → «Comp Add View» уже правильная.
- `su_component_add_view.rb:14`: версия 1.2.0 → **1.3.0**; `README.md:94` — версия.

### 2. dn1sup_time_project2 — фикс порядка загрузки
- `dn1sup_time_project2/dn1sup_time_project2/dn1sup_time_project2/main.rb:113–118`, `setup_ui`. Сейчас `return if $dn1sup_common_menu` — если чужой плагин создал DN1SUP раньше, свои пункты не добавляются вовсе (comp_add_view грузится раньше по алфавиту → баг сработает сразу). Заменить на:
  ```ruby
  parent = UI.menu('Extensions')
  $dn1sup_common_menu ||= parent.add_submenu(COMMON_MENU)
  return if $dn1sup_time_project2_menu   # горячая перезагрузка: пункты уже добавлены
  $dn1sup_time_project2_menu = $dn1sup_common_menu.add_submenu(MENU_NAME)
  ```
  Своя глобальная переменная сохраняет прежнюю защиту от дубля пунктов при hot reload.
- Bump версии, README (если упоминает путь меню).

### 3. dn1sup_autoselect_tag — перенос внутрь DN1SUP
- `dn1sup_autoselect_tag/dn1sup_autoselect_tag/dn1sup_autoselect_tag/main.rb:173`: вместо верхнеуровневого `'DN1Sup AutoSelect Tag'`:
  ```ruby
  menu = ($dn1sup_common_menu ||= UI.menu('Extensions').add_submenu('DN1SUP')).add_submenu('AutoSelect Tag')
  ```
- Bump версии, README.

### 4. dn1sup_export_pdf2 — перенос внутрь DN1SUP
- `dn1sup_export_pdf2/dn1sup_export_pdf2/main.rb:135–137`: вместо `UI.menu("Plugins") + add_submenu("#{NAME_EXTENSION} v#{PLUGIN_VERSION}")`:
  ```ruby
  dn1sup = ($dn1sup_common_menu ||= UI.menu('Extensions').add_submenu('DN1SUP'))
  submenu = dn1sup.add_submenu('Export PDF 2')
  ```
  (без версии в заголовке — единый стиль, версия видна в Extension Manager). Mock в `test/mock_sketchup.rb` совместим (`add_submenu` возвращает self).
- Bump версии (version.rb), README.

### 5. dn1sup_ext_manager — перенос внутрь DN1SUP
- `dn1sup_extensions/src/dn1sup_ext_manager/main.rb:481`: тот же паттерн, подменю `'Extension Store'` внутри DN1SUP.
- Bump версии.

### 6. Монорепозиторий dn1sup_extensions — релиз
- `registry.json`: обновить версии и добавить changelog-строки для обновлённых плагинов.
- Пересобрать .rbz через `tools/pack.rb` (сначала посмотреть, откуда он берёт исходники; export_pdf2 в packages/ отсутствует — его не пересобираем).

## Проверка
1. `ext_check` — синтаксис под Ruby 3.2 для каждого правленного main.rb.
2. Открыть SketchUp (`app_open`), `ext_install` + `ext_reload` каждого плагина из dev-копий, затем чистый перезапуск SketchUp (меню строятся при загрузке).
3. Программно: `$dn1sup_common_menu` не nil, команды пунктов отвечают.
4. Визуально: нативный скриншот открытого меню «Расширения» — один DN1SUP, внутри 5 подменю.
5. Подпункты внутри DN1SUP идут в порядке загрузки (по алфавиту) — API не позволяет управлять порядком.

## Коммиты
Отдельный коммит в каждом из 5 репозиториев в существующем стиле, например: `feat: nest app menu inside shared DN1SUP submenu, bump version to X.Y.Z` (для time_project2 — `fix:`).