# frozen_string_literal: true

require 'sketchup.rb'

module CustomTools
  module ComponentRotator
    module Rotator
      # Основная логика: Копирование слева + Поворот
      def self.rotate_selected
        model = Sketchup.active_model
        selection = model.selection

        if selection.empty?
          UI.messagebox('Пожалуйста, выделите компонент или группу.')
          return
        end

        z_deg, x_deg = Settings.get_settings

        # Начинаем единую операцию для отмены через Ctrl+Z
        model.start_operation('Копия слева и поворот Z-X', true)

        new_entities = []

        # Используем .to_a, чтобы не нарушать цикл при изменении выделения
        selection.to_a.each do |ent|
          next unless ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)

          # 1. Создаем копию объекта в том же контейнере (родительской группе/модели)
          parent_entities = ent.parent.entities
          copy = parent_entities.add_instance(ent.definition, ent.transformation)

          # 2. Рассчитываем сдвиг влево (по оси -X) на габаритную ширину объекта
          width = ent.bounds.width
          shift_left = Geom::Vector3d.new(-width, 0, 0)
          copy.transform!(Geom::Transformation.translation(shift_left))

          # 3. Поворачиваем созданную копию вокруг её новой точки вставки
          origin = copy.transformation.origin
          tr_z = Geom::Transformation.rotation(origin, Z_AXIS, z_deg.degrees)
          tr_x = Geom::Transformation.rotation(origin, X_AXIS, x_deg.degrees)

          # Порядок поворота: сначала Z, затем X
          total_tr = tr_x * tr_z
          copy.transform!(total_tr)

          new_entities << copy
        end

        # Переносим выделение на новые повернутые объекты
        unless new_entities.empty?
          selection.clear
          selection.add(new_entities)
        end

        model.commit_operation
      end
    end
  end
end
