# frozen_string_literal: true

require 'sketchup.rb'

module CustomTools
  module ComponentRotator
    # Модуль с логикой дублирования и поворота компонентов/групп
    module Rotator
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

        new_items = targets.map do |ent|
          # 1. При создании копии добавляем экземпляр в тот же контейнер и сдвигаем влево на габаритную ширину
          target = if make_copy
                     copy = ent.parent.entities.add_instance(ent.definition, ent.transformation)
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
      end
    end
  end
end
