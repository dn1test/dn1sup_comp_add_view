# frozen_string_literal: true

require 'sketchup.rb'
require 'json'

module CustomTools
  module ComponentAddViews
    # Живой 3D-предпросмотр операций панели: копии-призраки показывают конечное
    # положение объектов и обновляются при каждом изменении параметров; кнопка
    # «Применить» в панели снимает призраки и выполняет обычную операцию
    # Rotator, так что результат совпадает с предпросмотром, а Ctrl+Z отменяет
    # её одним шагом.
    #
    # Призраки живут внутри ОДНОЙ открытой операции («Предпросмотр»): смена
    # transformation у призраков не засоряет undo, отмена (abort_operation)
    # убирает их все одним шагом. Обратная сторона: ручные правки модели, пока
    # предпросмотр открыт, попали бы в ту же операцию — поэтому предпросмотр
    # автоматически снимается при смене выделения и смене инструмента
    # (наблюдатели в dialog.rb).
    module Preview
      KINDS = %i[rotate views].freeze

      class << self
        # Обновляет предпросмотр: при смене выделения или типа операции
        # пересоздаёт призраки, иначе только переставляет их (дёшево, без
        # пересоздания геометрии).
        # @param [String, Symbol] kind 'rotate' | 'views'
        # @param [Hash, String] params параметры панели (Hash или JSON-строка)
        # @return [Boolean] успешность
        def update(kind, raw = {})
          kind = kind.to_s.to_sym
          return cancel unless KINDS.include?(kind)

          params = parse(raw)
          @last ||= {}
          @last[kind] = params
          @last_kind = kind

          targets = active_targets
          return cancel if targets.empty?

          if rebuild_needed?(kind, targets)
            cancel
            Sketchup.active_model.start_operation('Предпросмотр', true)
            @op_open = true
            @op_kind = kind
            @op_targets = targets
            @ghost_sets = targets.map { |ent| make_ghosts(kind, ent) }
          end

          @ghost_sets.each_with_index do |set, i|
            ent = @op_targets[i]
            next unless ent.valid?

            kind == :views ? apply_views(set, ent, params) : apply_rotate(set[0], ent, params)
          end
          Sketchup.active_model.active_view.invalidate
          true
        rescue StandardError => e
          warn "[ComponentAddViews] Ошибка предпросмотра: #{e.message}"
          cancel
          false
        end

        # Закрепляет предпросмотр: снимает призраки, сохраняет переданные
        # настройки (на случай не дошедшего автосохранения) и выполняет
        # обычную операцию Rotator над текущим выделением.
        # @return [Boolean]
        def apply(kind, raw = {})
          kind = kind.to_s.to_sym
          cancel
          return false unless KINDS.include?(kind)

          save_params(parse(raw))
          if kind == :rotate
            Rotator.rotate_selected
          else
            Rotator.create_top_side_views
          end
          @last = nil # после применения автопродолжение предпросмотра не нужно
          true
        end

        # Снимает предпросмотр; безопасен, когда предпросмотр не активен.
        # @return [Boolean] был ли активен предпросмотр
        def cancel
          was_open = @op_open ? true : false
          Sketchup.active_model.abort_operation if was_open
          was_open
        rescue StandardError
          false
        ensure
          @op_open = false
          @op_kind = nil
          @op_targets = nil
          @ghost_sets = nil
        end

        # Активен ли сейчас предпросмотр
        # @return [Boolean]
        def active?
          !!@op_open
        end

        # Продолжает предпросмотр на новом выделении с прошлыми параметрами
        # (вызывается наблюдателем выделения, только если предпросмотр был
        # активен — см. Panel.selection_changed).
        # @return [Boolean]
        def refresh
          return false unless @last_kind && @last.is_a?(Hash) && @last.key?(@last_kind)

          update(@last_kind, @last[@last_kind])
        end

        private

        # Целевые объекты выделения (компоненты и группы) — как в Rotator
        # @return [Array(Sketchup::ComponentInstance, Sketchup::Group)]
        def active_targets
          Sketchup.active_model.selection.select do |e|
            e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          end
        end

        # Нужны ли новые призраки: сменился тип операции, часть призраков
        # стёрта или изменился состав выделения
        def rebuild_needed?(kind, targets)
          return true if @ghost_sets.nil? || @op_kind != kind
          return true unless @ghost_sets.all? { |set| set.all?(&:valid?) }

          old_ids = @op_targets.map { |e| e.valid? ? e.persistent_id.to_s : '?' }
          old_ids != targets.map { |e| e.persistent_id.to_s }
        end

        # Набор призраков для одного объекта: 1 для поворота,
        # 2 (вид сверху + вид сбоку) для проекций
        def make_ghosts(kind, ent)
          first = Rotator.duplicate_entity(ent)
          kind == :views ? [first, Rotator.duplicate_entity(ent)] : [first]
        end

        # Призрак поворота: в точности шаги Rotator.rotate_selected —
        # сдвиг копии влево на ширину (если make_copy), затем поворот вокруг
        # точки вставки: сначала Z, затем X
        def apply_rotate(ghost, ent, params)
          ghost.transformation = ent.transformation
          if bool_param(params['make_copy'])
            ghost.transform!(Geom::Transformation.translation([-ent.bounds.width, 0, 0]))
          end
          origin = ghost.transformation.origin
          z = num_param(params['angle_z'])
          x = num_param(params['angle_x'])
          ghost.transform!(
            Geom::Transformation.rotation(origin, X_AXIS, x.degrees) *
            Geom::Transformation.rotation(origin, Z_AXIS, z.degrees)
          )
        end

        # Призраки проекций: в точности шаги Rotator.create_top_side_views —
        # «вид сверху» (X +90°) над объектом, «вид сбоку» (Z ∓90°) сбоку,
        # отступ через Rotator.calculate_gap
        def apply_views(set, ent, params)
          top, side = set
          orig = ent.bounds
          gap = Rotator.calculate_gap(orig, params['offset'])
          t0 = ent.transformation

          top.transformation = t0
          top.transform!(Geom::Transformation.rotation(t0.origin, X_AXIS, 90.degrees))
          tb = top.bounds
          top.transform!(Geom::Transformation.translation(
            [orig.min.x - tb.min.x, orig.min.y - tb.min.y, (orig.max.z - tb.min.z) + gap]
          ))

          side_angle = (params['side_view'] == 'Слева') ? 90.0 : -90.0
          side.transformation = t0
          side.transform!(Geom::Transformation.rotation(t0.origin, Z_AXIS, side_angle.degrees))
          sb = side.bounds
          side.transform!(Geom::Transformation.translation(
            [(orig.max.x - sb.min.x) + gap, orig.min.y - sb.min.y, orig.min.z - sb.min.z]
          ))
        end

        # Сохраняет параметры панели в настройки (пишутся все 5 значений:
        # недостающие берутся из текущих настроек)
        def save_params(p)
          z, x, copy, side, offset = Settings.get_settings
          z = num_param(p['angle_z'], z)
          x = num_param(p['angle_x'], x)
          copy = bool_param(p['make_copy'], copy)
          side = p['side_view'] if %w[Справа Слева].include?(p['side_view'].to_s)
          offset = p['offset'].to_s.strip unless p['offset'].to_s.strip.empty?
          Settings.save_settings(z, x, copy, side, offset)
        end

        def parse(raw)
          h = raw.is_a?(String) ? JSON.parse(raw) : raw
          h.is_a?(Hash) ? h.transform_keys(&:to_s) : {}
        rescue JSON::ParserError
          {}
        end

        def num_param(v, fallback = 0.0)
          Float(v.to_s.tr(',', '.')) { fallback }
        end

        def bool_param(v, fallback = true)
          return fallback if v.nil?

          v != false && v != 'Нет'
        end
      end
    end
  end
end
