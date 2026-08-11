# frozen_string_literal: true

require 'sketchup.rb'

module CustomTools
  module ComponentRotator
    # Подключение внутренних модулей настроек и логики поворота
    require_relative 'settings'
    require_relative 'rotator'

    # Регистрация элементов пользовательского интерфейса (меню и тулбар)
    unless file_loaded?(__FILE__)
      # Создание команды поворота и настройка её параметров (подсказки, иконки)
      cmd_rotate = UI::Command.new('Повернуть') { Rotator.rotate_selected }.tap do |cmd|
        cmd.tooltip = 'Повернуть по Z и X'
        cmd.status_bar_text = 'Поворачивает объект (или создает копию слева) по осям Z и X'
        icon = File.join(__dir__, 'resources', 'rotate.svg')
        cmd.small_icon = cmd.large_icon = icon if File.exist?(icon)
      end

      # Пункты в меню «Расширения» (Plugins)
      menu = UI.menu('Plugins').add_submenu('ComponentRotator')
      menu.add_item(cmd_rotate)
      menu.add_item('Настройки...') { Settings.show_settings }

      # Панель инструментов (Toolbar)
      toolbar = UI::Toolbar.new('ComponentRotator')
      toolbar.add_item(cmd_rotate)
      toolbar.show

      file_loaded(__FILE__)
    end
  end
end
