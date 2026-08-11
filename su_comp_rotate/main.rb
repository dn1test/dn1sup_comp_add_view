# frozen_string_literal: true

require 'sketchup.rb'

module CustomTools
  module ComponentRotator
    # Загрузка внутренних модулей
    require_relative 'settings'
    require_relative 'rotator'

    # Регистрация элементов интерфейса (меню и панель инструментов)
    unless file_loaded?(__FILE__)
      resources_path = File.join(__dir__, 'resources')

      # 1. Пункты меню в "Расширения" (Plugins)
      menu = UI.menu('Plugins').add_submenu('Копия слева и Поворот Z-X')
      menu.add_item('Повернуть') { Rotator.rotate_selected }
      menu.add_item('Настройки...') { Settings.show_settings }

      # 2. Панель инструментов (Toolbar)
      toolbar = UI::Toolbar.new('Копия слева + Поворот')

      # Команда: Повернуть
      cmd_rotate = UI::Command.new('Повернуть') do
        Rotator.rotate_selected
      end
      cmd_rotate.tooltip = 'Повернуть по Z и X'
      cmd_rotate.status_bar_text = 'Поворачивает объект (или создает копию слева) по осям Z и X согласно настройкам'

      icon_rotate = File.join(resources_path, 'rotate.svg')
      if File.exist?(icon_rotate)
        cmd_rotate.small_icon = icon_rotate
        cmd_rotate.large_icon = icon_rotate
      end

      toolbar.add_item(cmd_rotate)
      toolbar.show

      file_loaded(__FILE__)
    end
  end
end
