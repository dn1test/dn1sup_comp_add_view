# frozen_string_literal: true

# Мини-заглушка SketchUp API для локального запуска тестов вне SketchUp
# (ruby test/main_test.rb — см. шапку test/main_test.rb). На $LOAD_PATH её
# подкладывает test_helper.rb и только когда Sketchup не определён; в пакет
# .rbz она не попадает (tools/ не пакуется — см. tools/pack.rb).
#
# Закрывает ровно то, что исполняется при загрузке main.rb (меню, тулбар,
# команда панели). Объектов модели нет: Sketchup.active_model возвращает nil,
# и все модельные тесты уходят в skip, как и задумано.

module Sketchup
  def self.active_model; end

  def self.version
    '0.0.0'
  end
end

# UI и Geom в настоящем API — модули верхнего уровня (не Sketchup::UI)
module UI
  class Command
    def initialize(_name); end

    def tooltip=(_); end

    def status_bar_text=(_); end

    def small_icon=(_); end

    def large_icon=(_); end
  end

  class Toolbar
    def initialize(_name); end

    def add_item(_); end

    def get_last_state
      -1
    end

    def show; end

    def restore; end
  end

  class Menu
    def add_submenu(_name)
      self
    end

    def add_item(_item = nil, &_block)
      self
    end

    def add_separator; end
  end

  def self.menu(_name)
    @menu ||= Menu.new
  end
end

# file_loaded?/file_loaded в настоящем sketchup.rb — методы верхнего уровня;
# хранилище глобальное, потому что вызываются с разными self.
$dn1sup_stub_loaded_files = {}

def file_loaded?(path)
  $dn1sup_stub_loaded_files[path.to_s] ? true : false
end

def file_loaded(path)
  $dn1sup_stub_loaded_files[path.to_s] = true
end
