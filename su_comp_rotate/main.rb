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
      menu.add_item('Создать копию и повернуть') { Rotator.rotate_selected }
      menu.add_item('Настройки...') { Settings.show_settings }

      # 2. Панель инструментов (Toolbar)
      toolbar = UI::Toolbar.new('Копия слева + Поворот')

      # Команда: Копировать и повернуть
      cmd_rotate = UI::Command.new('Копировать и повернуть') do
        Rotator.rotate_selected
      end
      cmd_rotate.tooltip = 'Создать копию слева и повернуть'
      cmd_rotate.status_bar_text = 'Создает копию объекта слева и поворачивает её сначала по Z, затем по X'

      icon_rotate = File.join(resources_path, 'rotate.svg')
      if File.exist?(icon_rotate)
        cmd_rotate.small_icon = icon_rotate
        cmd_rotate.large_icon = icon_rotate
      end

      # Команда: Настройки
      cmd_settings = UI::Command.new('Настройки') do
        Settings.show_settings
      end
      cmd_settings.tooltip = 'Настройки углов'
      cmd_settings.status_bar_text = 'Задать углы Z и X по умолчанию'

      icon_settings = File.join(resources_path, 'settings.svg')
      if File.exist?(icon_settings)
        cmd_settings.small_icon = icon_settings
        cmd_settings.large_icon = icon_settings
      end

      toolbar.add_item(cmd_rotate)
      toolbar.add_item(cmd_settings)
      toolbar.show

      file_loaded(__FILE__)
    end
  end
end
