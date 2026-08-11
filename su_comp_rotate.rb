require 'sketchup.rb'

module CustomTools
  module ComponentRotator
    # Ключ реестра для сохранения параметров
    REGISTRY_KEY = "CustomTools_ComponentRotator".freeze

    # Получение текущих сохраненных углов
    def self.get_settings
      z = Sketchup.read_default(REGISTRY_KEY, "angle_z", 0.0).to_f
      x = Sketchup.read_default(REGISTRY_KEY, "angle_x", 0.0).to_f
      [z, x]
    end

    # Сохранение углов
    def self.save_settings(z, x)
      Sketchup.write_default(REGISTRY_KEY, "angle_z", z.to_f)
      Sketchup.write_default(REGISTRY_KEY, "angle_x", x.to_f)
    end

    # Окно настройки параметров
    def self.show_settings
      current_z, current_x = get_settings
      
      prompts = ["Угол Z (сначала):", "Угол X (затем):"]
      defaults = [current_z, current_x]
      
      results = UI.inputbox(prompts, defaults, "Настройки поворота (Z -> X)")
      return unless results
      
      save_settings(results[0], results[1])
      puts "Новые углы по умолчанию сохранены: Z=#{results[0]}, X=#{results[1]}"
    end

    # Основная логика: Копирование слева + Поворот
    def self.rotate_selected
      model = Sketchup.active_model
      selection = model.selection
      
      if selection.empty?
        UI.messagebox("Пожалуйста, выделите компонент или группу.")
        return
      end

      z_deg, x_deg = get_settings
      
      # Начинаем единую операцию для отмены через Ctrl+Z
      model.start_operation('Копия слева и поворот Z-X', true)
      
      new_entities = []

      # Используем .to_a, чтобы не нарушать цикл при изменении выделения
      selection.to_a.each do |ent|
        if ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)
          
          # 1. Создаем копию объекта в том же контейнере (родительской группе/сцене)
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
      end
      
      # Переносим выделение на новые повернутые объекты
      unless new_entities.empty?
        selection.clear
        selection.add(new_entities)
      end

      model.commit_operation
    end

    # Регистрация меню и панели
    unless file_loaded?(__FILE__)
      
      menu = UI.menu("Plugins").add_submenu("Копия слева и Поворот Z-X")
      menu.add_item("Создать копию и повернуть") { self.rotate_selected }
      menu.add_item("Настройки...") { self.show_settings }
      
      toolbar = UI::Toolbar.new("Копия слева + Поворот")
      
      cmd_rotate = UI::Command.new("Копировать и повернуть") { self.rotate_selected }
      cmd_rotate.tooltip = "Создать копию слева и повернуть"
      cmd_rotate.status_bar_text = "Создает копию объекта слева и поворачивает её сначала по Z, затем по X"
      
      cmd_settings = UI::Command.new("Настройки") { self.show_settings }
      cmd_settings.tooltip = "Настройки углов"
      cmd_settings.status_bar_text = "Задать углы Z и X по умолчанию"
      
      toolbar = toolbar.add_item cmd_rotate
      toolbar = toolbar.add_item cmd_settings
      toolbar.show
      
      file_loaded(__FILE__)
    end
  end
end