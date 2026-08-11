# frozen_string_literal: true

require 'sketchup.rb'

module CustomTools
  module ComponentAddViews
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

      # Создание команды создания 2 копий: вид сверху и вид сбоку
      cmd_views = UI::Command.new('Вид сверху и сбоку') { Rotator.create_top_side_views }.tap do |cmd|
        cmd.tooltip = 'Создать 2 копии: вид сверху и сбоку'
        cmd.status_bar_text = 'Создает две повернутые копии выделенного объекта (вид сверху и вид сбоку)'
        icon = File.join(__dir__, 'resources', 'views.svg')
        cmd.small_icon = cmd.large_icon = icon if File.exist?(icon)
      end

      # Пункты в меню «Расширения» (Plugins)
      menu = UI.menu('Plugins').add_submenu('ComponentAddViews')
      menu.add_item(cmd_rotate)
      menu.add_item(cmd_views)
      menu.add_separator
      menu.add_item('Настройки...') { Settings.show_settings }

      # Панель инструментов (Toolbar)
      toolbar = UI::Toolbar.new('ComponentAddViews')
      toolbar.add_item(cmd_rotate)
      toolbar.add_item(cmd_views)
      toolbar.show

      file_loaded(__FILE__)
    end
  end
end

