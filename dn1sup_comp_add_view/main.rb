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
    VERSION  = '0.13.0'.freeze

    ID       = 'dn1sup_comp_add_view'.freeze
    REPO     = 'dn1test/dn1sup_comp_add_view'.freeze
    ASSET    = "#{ID}.rbz".freeze
    PAGE_URL = "https://github.com/#{REPO}/releases".freeze
    MANIFEST = { id: ID, repo: REPO, version: VERSION, asset: ASSET }.freeze

    # Подключение внутренних модулей настроек, логики поворота, предпросмотра и панели
    require_relative 'settings'
    require_relative 'rotator'
    require_relative 'preview'
    require_relative 'dialog'

    # Выгрузка неймспейса при переключении канала dev/prod (dn1sup_ext_manager,
    # метод switch_extension): остановка таймера проверки обновлений, закрытие
    # панели, скрытие тулбара. Меню через SketchUp API не удаляются — пункты
    # старого канала остаются до перезапуска SketchUp (известное ограничение).
    # @return [Boolean]
    def self.unload!
      if defined?(UI) && UI.respond_to?(:stop_timer) && @update_timer_id
        UI.stop_timer(@update_timer_id)
        @update_timer_id = nil
      end
      Panel.close_all if defined?(Panel) && Panel.respond_to?(:close_all)
      # Прячем только реально созданную панель: конструирование UI::Toolbar
      # для несуществующей регистрирует её в списке панелей SketchUp.
      if defined?(UI) && Sketchup.respond_to?(:read_default) &&
         Sketchup.read_default('DN1Sup ExtManager', 'shared_toolbar_show_individual')
        toolbar = UI::Toolbar.new('DN1Sup Comp Add View')
        toolbar.hide if toolbar.respond_to?(:visible?) && toolbar.visible?
      end
      true
    rescue StandardError => e
      warn "[ComponentAddViews] unload!: #{e.message}"
      false
    end

    # Регистрация элементов пользовательского интерфейса (меню и тулбар)
    unless file_loaded?(__FILE__)
      # Единственная команда тулбара — открытие панели управления (HtmlDialog
      # на Vue 3 + Tailwind): операции и настройки живут только в панели,
      # старые кнопки «Повернуть» / «Вид сверху и сбоку» заменены ею
      cmd_panel = UI::Command.new('Панель Comp Add View') { Panel.show }.tap do |cmd|
        cmd.tooltip = 'Панель Comp Add View'
        cmd.status_bar_text = 'Открывает панель управления: поворот, проекции, настройки и предпросмотр'
        icon = File.join(__dir__, 'resources', 'panel.svg')
        cmd.small_icon = cmd.large_icon = icon if File.exist?(icon)
      end

      # Общее подменю DN1Sup в меню «Расширения» — синглтон в корневом модуле Dn1sup,
      # разделяется всеми расширениями DN1Sup (API не умеет искать существующие
      # подменю по имени — add_submenu всегда создаёт новое).
      dn1sup_menu = Dn1sup.common_menu

      # Пункты расширения — в подменю «Comp Add View» внутри DN1Sup
      menu = dn1sup_menu.add_submenu('Comp Add View')
      menu.add_item(cmd_panel)
      menu.add_item('Настройки...') { Panel.show }
      menu.add_separator
      menu.add_item('Проверить обновления сейчас') do
        if defined?(Dn1sup::Updater)
          Dn1sup::Updater.check!(CustomTools::ComponentAddViews::MANIFEST.merge(force: true, async: true))
        else
          UI.openURL(CustomTools::ComponentAddViews::PAGE_URL)
        end
      end
      menu.add_item('Страница релизов на GitHub') { UI.openURL(CustomTools::ComponentAddViews::PAGE_URL) }

      # Панель инструментов — одна кнопка открытия панели. Не создаём её,
      # пока включена общая панель DN1Sup (параметр «Показывать отдельные
      # тулбары расширений» выключен): тогда тулбара нет и в списке панелей
      # SketchUp; состав общей панели настраивается в менеджере.
      if Sketchup.respond_to?(:read_default) &&
         Sketchup.read_default('DN1Sup ExtManager', 'shared_toolbar_show_individual')
        toolbar = UI::Toolbar.new('DN1Sup Comp Add View')
        toolbar.add_item(cmd_panel)

        if toolbar.get_last_state == -1
          toolbar.show
        else
          toolbar.restore
        end
      end

      # Фоновая проверка обновлений один раз за сессию (не раньше 15 секунд,
      # чтобы не мешать загрузке SketchUp).
      unless $dn1sup_cav_update_check_scheduled
        $dn1sup_cav_update_check_scheduled = true
        if defined?(Dn1sup::Updater) && UI.respond_to?(:start_timer)
          # id таймера хранится в ivar неймспейса: unload! останавливает его
          # при переключении канала, иначе таймер переживёт remove_const.
          @update_timer_id = UI.start_timer(15, false) do
            Dn1sup::Updater.check!(CustomTools::ComponentAddViews::MANIFEST.merge(async: true))
          end
        end
      end

      file_loaded(__FILE__)
    end
  end
end


