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
          z, x, copy, side, offset = Settings.get_settings
          { angle_z: z, angle_x: x, make_copy: copy, side_view: side, offset: offset, version: VERSION }
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

        private

        def bring_to_front
          @dialog.bring_to_front
          push_selection
          @dialog
        end

        def build_dialog
          dlg = UI::HtmlDialog.new(DIALOG_OPTIONS)
          dlg.add_action_callback('settings_get') { |_ctx, req_id| push_event('result', id: req_id, payload: settings_hash) }
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
          dlg.add_action_callback('preview_cancel') { |_ctx, _req_id| Preview.cancel }
          dlg.add_action_callback('open_releases') { UI.openURL(PAGE_URL) }
          dlg.set_on_closed do
            Preview.cancel
            detach_observers
          end
          dlg
        end

        # Сохранение настроек из параметров панели (Hash со строковыми ключами
        # или JSON-строка); возвращает свежий хеш настроек
        def save_from_panel(params)
          data = params.is_a?(String) ? JSON.parse(params) : params
          data = {} unless data.is_a?(Hash)
          data = data.transform_keys(&:to_s)
          Settings.save_settings(
            data['angle_z'], data['angle_x'], data['make_copy'], data['side_view'], data['offset']
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
        # выделение (если был активен) либо снимается; состояние уходит в панель
        def selection_changed
          was_active = Preview.active?
          Preview.cancel
          Preview.refresh if was_active
          push_selection
        end

        def attach_selection_observer
          return if !defined?(Sketchup::SelectionObserver) || @observer

          @observer = SelectionObserver.new
          Sketchup.active_model.add_selection_observer(@observer)
          if defined?(Sketchup::ToolsObserver)
            @tools_observer = ToolsObserver.new
            Sketchup.active_model.tools.add_tools_observer(@tools_observer)
          end
        end

        def detach_observers
          return unless @observer

          if defined?(Sketchup::SelectionObserver)
            Sketchup.active_model.remove_selection_observer(@observer)
          end
          if @tools_observer && defined?(Sketchup::ToolsObserver)
            Sketchup.active_model.tools.remove_tools_observer(@tools_observer)
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
