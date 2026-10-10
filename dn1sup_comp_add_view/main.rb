# frozen_string_literal: true

require 'sketchup.rb'

# Общий модуль автообновления dn1sup_updater.rb кладётся в пакет при упаковке
# (tools/pack.rb); в dev-копии его нет. LoadError не наследуется от
# StandardError — ловим явно (SU2026+ пробрасывает).
if defined?(Sketchup) && Sketchup.respond_to?(:require)
  begin
    Sketchup.require 'dn1sup_comp_add_view/dn1sup_updater'
  rescue LoadError, StandardError
    nil
  end
end

module Dn1sup
  def self.common_menu
    @common_menu ||= UI.menu('Extensions').add_submenu('DN1Sup')
  end
end

module CustomTools
  module ComponentAddViews
    VERSION  = '0.4.2'.freeze

    ID       = 'dn1sup_comp_add_view'.freeze
    REPO     = 'dn1test/dn1sup_comp_add_view'.freeze
    ASSET    = "#{ID}.rbz".freeze
    PAGE_URL = "https://github.com/#{REPO}/releases".freeze
    MANIFEST = { id: ID, repo: REPO, version: VERSION, asset: ASSET }.freeze

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

      # Общее подменю DN1Sup в меню «Расширения» — синглтон в корневом модуле Dn1sup,
      # разделяется всеми расширениями DN1Sup (API не умеет искать существующие
      # подменю по имени — add_submenu всегда создаёт новое).
      dn1sup_menu = Dn1sup.common_menu

      # Пункты расширения — в подменю «Comp Add View» внутри DN1Sup
      menu = dn1sup_menu.add_submenu('Comp Add View')
      menu.add_item(cmd_rotate)
      menu.add_item(cmd_views)
      menu.add_separator
      menu.add_item('Настройки...') { Settings.show_settings }
      menu.add_separator
      menu.add_item('Проверить обновления сейчас') do
        if defined?(Dn1sup::Updater)
          Dn1sup::Updater.check!(CustomTools::ComponentAddViews::MANIFEST.merge(force: true, async: true))
        else
          UI.openURL(CustomTools::ComponentAddViews::PAGE_URL)
        end
      end
      menu.add_item('Страница релизов на GitHub') { UI.openURL(CustomTools::ComponentAddViews::PAGE_URL) }

      # Панель инструментов (Toolbar)
      toolbar = UI::Toolbar.new('DN1Sup Comp Add View')
      toolbar.add_item(cmd_rotate)
      toolbar.add_item(cmd_views)

      if toolbar.get_last_state == -1
        toolbar.show
      else
        toolbar.restore
      end

      # Фоновая проверка обновлений один раз за сессию (не раньше 15 секунд,
      # чтобы не мешать загрузке SketchUp).
      unless $dn1sup_cav_update_check_scheduled
        $dn1sup_cav_update_check_scheduled = true
        if defined?(Dn1sup::Updater) && UI.respond_to?(:start_timer)
          UI.start_timer(15, false) do
            Dn1sup::Updater.check!(CustomTools::ComponentAddViews::MANIFEST.merge(async: true))
          end
        end
      end

      file_loaded(__FILE__)
    end
  end
end


