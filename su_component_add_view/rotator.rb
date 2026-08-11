# frozen_string_literal: true

require 'sketchup.rb'

module CustomTools
  module ComponentAddViews
    # Модуль с логикой дублирования и поворота компонентов/групп
    module Rotator
      # Создает дубликат компонента или группы в том же родительском контейнере
      # @param [Sketchup::ComponentInstance, Sketchup::Group] ent исходный объект
      # @return [Sketchup::ComponentInstance, Sketchup::Group] созданный дубликат
      def self.duplicate_entity(ent)
        if ent.is_a?(Sketchup::Group)
          copy = ent.copy
          copy.make_unique if copy.respond_to?(:make_unique)
          copy
        elsif ent.respond_to?(:definition)
          ent.parent.entities.add_instance(ent.definition, ent.transformation)
        else
          ent_def = ent.entities.parent
          ent.parent.entities.add_instance(ent_def, ent.transformation)
        end
      end

      # Выполняет копирование слева (опционально) и поворот выделенных объектов вокруг осей Z и X
      # @return [void]
      def self.rotate_selected
        model = Sketchup.active_model
        # Фильтруем объекты: обрабатываем только компоненты и группы
        targets = model.selection.select { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }

        return UI.messagebox('Пожалуйста, выделите компонент или группу.') if targets.empty?

        # Загрузка параметров из конфигурационного файла
        z_deg, x_deg, make_copy = Settings.get_settings
        op_name = make_copy ? 'Копия слева и поворот Z-X' : 'Поворот Z-X'

        # Единая операция для поддержки отмены одним шагом (Ctrl+Z)
        model.start_operation(op_name, true)
        begin
          new_items = targets.map do |ent|
            # 1. При создании копии добавляем экземпляр в тот же контейнер и сдвигаем влево на габаритную ширину
            target = if make_copy
                       copy = duplicate_entity(ent)
                       shift_left = Geom::Transformation.translation([-ent.bounds.width, 0, 0])
                       copy.transform!(shift_left)
                       copy
                     else
                       ent
                     end

            # 2. Вычисляем поворот вокруг точки вставки: сначала вокруг Z, затем вокруг X
            origin = target.transformation.origin
            rot = Geom::Transformation.rotation(origin, X_AXIS, x_deg.degrees) *
                  Geom::Transformation.rotation(origin, Z_AXIS, z_deg.degrees)
            target.transform!(rot)

            target
          end

          # При создании копий переносим выделение на новые повернутые объекты
          if make_copy && !new_items.empty?
            model.selection.clear
            model.selection.add(new_items)
          end

          model.commit_operation
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Ошибка при повороте: #{e.message}")
          warn "[ComponentAddViews] #{e.message}\n#{e.backtrace.join("\n")}"
        end
      end

      # Вычисляет отступ на основе настройки (% от максимального габарита или фиксированные мм)
      # @param [Geom::BoundingBox] bounds габарит объекта
      # @param [String, Numeric] offset_setting настройка отступа ('20%' или '150')
      # @return [Length] отступ в единицах модели
      def self.calculate_gap(bounds, offset_setting)
        str = offset_setting.to_s.strip.delete(' ').tr(',', '.')
        if str.include?('%')
          percent = str.delete('%').to_f
          percent = 20.0 if percent <= 0
          max_dim = [bounds.width, bounds.height, bounds.depth].max
          [max_dim * (percent / 100.0), 10.mm].max
        else
          val = str.to_f
          (val > 0 ? val : 50.0).mm
        end
      end

      # Создает 2 копии выделенных объектов: вид сверху (сверху) и вид сбоку (справа)
      # @return [void]
      def self.create_top_side_views
        model = Sketchup.active_model
        # Фильтруем объекты: обрабатываем только компоненты и группы
        targets = model.selection.select { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }

        return UI.messagebox('Пожалуйста, выделите компонент или группу.') if targets.empty?

        _z, _x, _copy, side_view, offset_setting = Settings.get_settings

        # Единая операция для поддержки отмены одним шагом (Ctrl+Z)
        model.start_operation('Копии: вид сверху и сбоку', true)
        begin
          new_items = []

          targets.each do |ent|
            orig_bounds = ent.bounds
            gap = calculate_gap(orig_bounds, offset_setting)

            # 1. Копия «Вид сверху»: поворот по оси X на +90° и позиционирование сверху над исходным объектом с отступом
            copy_top = duplicate_entity(ent)
            rot_top = Geom::Transformation.rotation(copy_top.transformation.origin, X_AXIS, 90.degrees)
            copy_top.transform!(rot_top)

            top_bounds = copy_top.bounds
            dx_top = orig_bounds.min.x - top_bounds.min.x
            dy_top = orig_bounds.min.y - top_bounds.min.y
            dz_top = (orig_bounds.max.z - top_bounds.min.z) + gap
            copy_top.transform!(Geom::Transformation.translation([dx_top, dy_top, dz_top]))
            new_items << copy_top

            # 2. Копия «Вид сбоку»: поворот по оси Z (-90° для вида справа, +90° для вида слева) и позиционирование справа с отступом
            copy_side = duplicate_entity(ent)
            side_angle = (side_view == 'Слева') ? 90.0 : -90.0
            rot_side = Geom::Transformation.rotation(copy_side.transformation.origin, Z_AXIS, side_angle.degrees)
            copy_side.transform!(rot_side)

            side_bounds = copy_side.bounds
            dx_side = (orig_bounds.max.x - side_bounds.min.x) + gap
            dy_side = orig_bounds.min.y - side_bounds.min.y
            dz_side = orig_bounds.min.z - side_bounds.min.z
            copy_side.transform!(Geom::Transformation.translation([dx_side, dy_side, dz_side]))
            new_items << copy_side
          end

          # Выделяем созданные копии
          unless new_items.empty?
            model.selection.clear
            model.selection.add(new_items)
          end

          model.commit_operation
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Ошибка при создании проекций: #{e.message}")
          warn "[ComponentAddViews] #{e.message}\n#{e.backtrace.join("\n")}"
        end
      end
    end
  end
end



