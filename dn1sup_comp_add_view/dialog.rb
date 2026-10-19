# frozen_string_literal: true

require 'sketchup.rb'
require 'json'

module CustomTools
  module ComponentAddViews
    # Панель управления (UI::HtmlDialog на Vue 3 + Tailwind): операции
    # «Повернуть» и «Вид сверху и сбоку», настройки и живые схемы предпросмотра.
    # Панель НЕ модальная — при открытом окне можно выделять объекты в модели;
    # состояние выделения пушится в панель наблюдателем SelectionObserver.
    #
    # Мост JS↔Ruby: в SU2026 (Qt WebEngine) возврата значений из колбэков нет —
    # ответы уходят в панель пушем через execute_script (window.__dn1Event),
    # запросы из JS приходят прямыми вызовами sketchup.<имя_колбэка>(id, json).
    module Panel
      PANEL_HTML = File.join(__dir__, 'resources', 'panel.html')

      DIALOG_OPTIONS = {
        dialog_title: 'DN1Sup Comp Add View',
        preferences_key: 'dn1sup_comp_add_view.panel',
        resizable: true,
        width: 460,
        height: 760,
        min_width: 380,
        min_height: 560
      }.freeze

      class << self
        attr_reader :dialog

        # Открывает панель (или поднимает уже открытое окно)
        # @return [UI::HtmlDialog, nil]
        def show
          return bring_to_front if @dialog&.visible?

          @dialog = build_dialog
          attach_selection_observer
          @dialog.set_file(PANEL_HTML)
          @dialog.show
          @dialog
        rescue StandardError => e
          warn "[ComponentAddViews] Не удалось открыть панель: #{e.message}"
          UI.messagebox("Не удалось открыть панель: #{e.message}")
          nil
        end

        # Закрытие панели при выгрузке неймспейса (переключение канала dev/prod,
        # unload!): окно закрывается (set_on_closed снимает наблюдатели и
        # предпросмотр), ссылка забывается — следующий show создаст свежий диалог.
        # @return [Boolean]
        def close_all
          return false unless @dialog

          begin
            @dialog.close if @dialog.visible?
          rescue StandardError
            nil
          end
          detach_observers
          Preview.cancel
          @dialog = nil
          true
        end

        # Снимок выделения: сколько всего выделено и сколько подходит
        # (компоненты/группы — целевые объекты операций)
        # @return [Hash{Symbol => Integer}]
        def selection_info
          sel = Sketchup.active_model.selection
          targets = sel.count { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
          { total: sel.size, targets: targets }
        end

        # Настройки одним хешем для панели (кортеж Settings.get_settings)
        # @return [Hash]
        def settings_hash
          z, x, copy, side, offset, rot180, language, theme = Settings.get_settings
          { angle_z: z, angle_x: x, make_copy: copy, side_view: side, offset: offset,
            rot180: rot180, language: language, theme: theme, version: VERSION }
        end

        # Пушит событие в панель: window.__dn1Event({type:, id:, payload:}).
        # Событие с id резолвит промис ожидающего callRuby, без id — уходит
        # подписчикам onEvent (например, смена выделения).
        # @return [void]
        def push_event(type, id: nil, payload: nil)
          return unless @dialog&.visible?

          evt = { type: type }
          evt[:id] = id if id
          evt[:payload] = payload if payload
          @dialog.execute_script("window.__dn1Event && window.__dn1Event(#{JSON.generate(evt)});")
        rescue StandardError => e
          warn "[ComponentAddViews] Не удалось отправить событие в панель: #{e.message}"
        end

        # Пушит состояние выделения в панель (колбэки операций и наблюдатель)
        # @return [void]
        def push_selection
          push_event('selection', payload: selection_info)
        end

        # Payload панели: HtmlDialog присылает JSON-строку (Hash бывает в
        # тестах и прямых вызовах); битая строка и не-Hash дают пустой хеш —
        # колбэки не должны падать или молча терять данные на мусорном входе
        # @return [Hash{String => Object}]
        def parse_panel_payload(params)
          data = params.is_a?(String) ? (JSON.parse(params) rescue nil) : params
          data.is_a?(Hash) ? data : {}
        end

        # Стадии проверки/установки обновления (status_cb апдейтера, вызывается
        # на главном потоке): статус запоминается даже при закрытой панели —
        # переоткрытая панель покажет последнее состояние, а открытой уходит
        # событие 'update_status' для статус-бара.
        # @return [void]
        def record_update_status(status)
          @last_update_status = status
          push_event('update_status', payload: status)
        end

        private

        def bring_to_front
          @dialog.bring_to_front
          push_selection
          @dialog
        end

        def build_dialog
          dlg = UI::HtmlDialog.new(DIALOG_OPTIONS)
          dlg.add_action_callback('settings_get') do |_ctx, req_id|
            push_event('result', id: req_id, payload: settings_hash)
            # Переоткрытая панель сразу показывает последнее состояние обновления
            push_event('update_status', payload: @last_update_status) if @last_update_status
          end
          dlg.add_action_callback('settings_save') { |_ctx, req_id, params| push_event('result', id: req_id, payload: save_from_panel(params)) }
          dlg.add_action_callback('selection_info') { |_ctx, req_id| push_event('result', id: req_id, payload: selection_info) }
          # Предпросмотры: JS шлёт их при каждом изменении параметров (с дебаунсом),
          # «Применить» в панели закрепляет результат обычной операцией Rotator
          dlg.add_action_callback('preview_update') { |_ctx, req_id, params|
            Preview.update(:rotate, params)
            push_event('result', id: req_id, payload: { preview: Preview.active? })
          }
          dlg.add_action_callback('preview_views_update') { |_ctx, req_id, params|
            Preview.update(:views, params)
            push_event('result', id: req_id, payload: { preview: Preview.active? })
          }
          dlg.add_action_callback('preview_apply') { |_ctx, req_id, params|
            Preview.apply(:rotate, params)
            push_selection
            push_event('result', id: req_id, payload: { action: 'rotate' })
          }
          dlg.add_action_callback('preview_views_apply') { |_ctx, req_id, params|
            Preview.apply(:views, params)
            push_selection
            push_event('result', id: req_id, payload: { action: 'views' })
          }
          # Комбинированное «Применить»: подмножество операций (галочки панели)
          # над одним и тем же выделением — apply_many восстанавливает выделение
          # между шагами. kinds извлекаются из разобранного payload (панель шлёт
          # JSON-строку), ok сообщает панели о неудаче — нет подходящего выделения
          dlg.add_action_callback('preview_apply_many') { |_ctx, req_id, params|
            data = parse_panel_payload(params)
            kinds = Array(data['kinds'])
            ok = Preview.apply_many(kinds, data)
            push_selection
            push_event('result', id: req_id, payload: { action: 'many', kinds: kinds, ok: ok })
          }
          dlg.add_action_callback('preview_cancel') { |_ctx, _req_id| Preview.cancel }
          dlg.add_action_callback('open_releases') { UI.openURL(PAGE_URL) }
          # Кнопка «круг со стрелками» в шапке панели: проверка релиза на GitHub.
          # status_cb уводит все стадии проверки/установки в статус-бар панели —
          # апдейтер при нём подавляет нативные messagebox промежуточных
          # состояний (вопрос «установить сейчас?» остаётся нативным).
          dlg.add_action_callback('check_update') do
            if defined?(Dn1sup::Updater)
              Dn1sup::Updater.check!(
                MANIFEST.merge(force: true, async: true,
                               status_cb: ->(st) { record_update_status(st) })
              )
            else
              UI.openURL(PAGE_URL)
            end
          end
          dlg.set_on_closed do
            Preview.cancel
            detach_observers
          end
          dlg
        end

        # Сохранение настроек из параметров панели (Hash со строковыми ключами
        # или JSON-строка); возвращает свежий хеш настроек
        def save_from_panel(params)
          data = parse_panel_payload(params).transform_keys(&:to_s)
          data = data.transform_keys(&:to_s)
          Settings.save_settings(
            data['angle_z'], data['angle_x'], data['make_copy'], data['side_view'], data['offset'],
            data['rot180'], data['language'], data['theme']
          )
          settings_hash
        rescue StandardError => e
          warn "[ComponentAddViews] Не удалось сохранить настройки из панели: #{e.message}"
          settings_hash
        end

        def run_action(method)
          Rotator.public_send(method)
          push_selection
        end

        # Любое изменение выделения: предпросмотр переносится на новое
        # выделение (если был активен) либо снимается; состояние уходит в панель.
        #
        # Тело откладывается в одноразовый таймер (с коалесценцией пачки
        # событий bulk+added/removed): SU2026.2 (Qt WebEngine) молча теряет
        # execute_script, вызванный синхронно из колбэка наблюдателя, — пуш
        # из контекста таймера доходит. Заодно abort_operation предпросмотра
        # (откатывающий выделение) перестаёт реентерабельно дёргать наблюдателя.
        def selection_changed
          return if @selection_timer

          @selection_timer = UI.start_timer(0.05, false) do
            @selection_timer = nil
            was_active = Preview.active?
            Preview.cancel
            Preview.refresh if was_active
            push_selection
          end
        end

        # SketchUp 2026.2 удалил типовые методы наблюдателей
        # (add_selection_observer, add_tools_observer, …) — остался единый
        # add_observer/remove_observer на коллекциях (model.selection, model.tools)
        # с теми же именами колбэков; в старых версиях работают типовые методы.
        # Возвращает true, только если наблюдатель выделения реально приаттачен;
        # при неудаче @observer сбрасывается — следующее открытие панели
        # повторит попытку.
        # @return [Boolean]
        def attach_selection_observer
          return true if @observer
          return false unless defined?(Sketchup::SelectionObserver)

          model = Sketchup.active_model
          @observer = SelectionObserver.new
          attached =
            if model.respond_to?(:add_selection_observer)
              !model.add_selection_observer(@observer).equal?(false)
            elsif model.selection.respond_to?(:add_observer)
              !model.selection.add_observer(@observer).equal?(false)
            else
              false
            end
          unless attached
            warn "[ComponentAddViews] Не удалось приаттачить наблюдатель выделения (SketchUp #{Sketchup.version}) — панель будет обновлять выделение опросом"
            @observer = nil
            return false
          end

          attach_tools_observer(model)
          true
        end

        # Наблюдатель инструментов необязателен: без него предпросмотр просто
        # не снимается сам при смене инструмента
        def attach_tools_observer(model)
          return unless defined?(Sketchup::ToolsObserver)

          tools = model.tools
          @tools_observer = ToolsObserver.new
          attached =
            if tools.respond_to?(:add_tools_observer)
              !tools.add_tools_observer(@tools_observer).equal?(false)
            elsif tools.respond_to?(:add_observer)
              !tools.add_observer(@tools_observer).equal?(false)
            else
              false
            end
          return if attached

          warn '[ComponentAddViews] Наблюдатель инструментов не приаттачен — предпросмотр не снимается при смене инструмента'
          @tools_observer = nil
        end

        def detach_observers
          if @selection_timer
            UI.stop_timer(@selection_timer)
            @selection_timer = nil
          end
          return unless @observer

          model = Sketchup.active_model
          if model.respond_to?(:remove_selection_observer)
            model.remove_selection_observer(@observer)
          elsif model.selection.respond_to?(:remove_observer)
            model.selection.remove_observer(@observer)
          end
          if @tools_observer && defined?(Sketchup::ToolsObserver)
            tools = model.tools
            if tools.respond_to?(:remove_tools_observer)
              tools.remove_tools_observer(@tools_observer)
            elsif tools.respond_to?(:remove_observer)
              tools.remove_observer(@tools_observer)
            end
          end
          @observer = nil
          @tools_observer = nil
        end
      end

      # Наблюдатель выделения: пока панель открыта, любое изменение выделения
      # в модели обновляет индикатор панели и переносит/снимает предпросмотр
      # без опроса со стороны JS.
      if defined?(Sketchup::SelectionObserver)
        class SelectionObserver
          def onSelectionBulkChange(_selection)
            Panel.selection_changed
          end

          def onSelectionAdded(_a, _entity)
            Panel.selection_changed
          end

          def onSelectionRemoved(_a, _entity)
            Panel.selection_changed
          end

          def onSelectionCleared(_selection)
            Panel.selection_changed
          end
        end
      end

      # Наблюдатель инструмента: пользователь ушёл работать в модель вручную —
      # открытая операция предпросмотра снимается, чтобы не поглотить его правки
      # (см. комментарий модуля Preview).
      if defined?(Sketchup::ToolsObserver)
        class ToolsObserver
          def onActiveToolChanged(_tools, _tool_name, _tool_id)
            Preview.cancel
          end
        end
      end
    end
  end
end
