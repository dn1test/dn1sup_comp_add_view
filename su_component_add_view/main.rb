# frozen_string_literal: true

require 'sketchup.rb'

module Dn1sup
  def self.common_menu
    @common_menu ||= begin
      legacy = (defined?($dn1sup_common_menu) && $dn1sup_common_menu) || (defined?($dn1sup_menu) && $dn1sup_menu)
      legacy || UI.menu('Extensions').add_submenu('DN1Sup')
    end
  end
end

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

      # Общее подменю DN1Sup в меню «Расширения» — разделяется всеми расширениями DN1Sup.
      # API не умеет искать существующие подменю по имени (add_submenu всегда создаёт новое),
      # поэтому первое загрузившееся расширение создаёт подменю и кладёт его в
      # Общее подменю DN1Sup в меню «Расширения» — синглтон в корневом модуле Dn1sup,
      # разделяется всеми расширениями DN1Sup без глобальных переменных.
      dn1sup_menu = Dn1sup.common_menu

      # Пункты расширения — в подменю «Comp Add View» внутри DN1Sup
      menu = dn1sup_menu.add_submenu('Comp Add View')
      menu.add_item(cmd_rotate)
      menu.add_item(cmd_views)
      menu.add_separator
      menu.add_item('Настройки...') { Settings.show_settings }

      # Панель инструментов (Toolbar)
      toolbar = UI::Toolbar.new('DN1Sup Comp Add View')
      toolbar.add_item(cmd_rotate)
      toolbar.add_item(cmd_views)

      if toolbar.get_last_state == -1
        toolbar.show
      else
        toolbar.restore
      end

      file_loaded(__FILE__)
    end
  end
end


