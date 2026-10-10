# frozen_string_literal: true
# =============================================================================
# dn1sup_comp_add_view/test/main_test.rb — тесты расширения
# «DN1Sup Component Add View».
# Запуск: внутри SketchUp через ext_test (MCP sketchup-dev);
# локально — ruby test/main_test.rb (модельные тесты уйдут в skip).
#
# Тесты не трогают настройки пользователя (save_settings не вызывается)
# и не показывают модальных диалогов — они подвесили бы мост MCP.
# =============================================================================

require_relative 'test_helper'

module CustomTools
  module ComponentAddViews
    module Test
      test 'версия расширения задана' do
        assert(/\A\d+\.\d+\.\d+\z/.match?(VERSION), "неожидаемый формат версии: #{VERSION.inspect}")
      end

      test 'версии регистратора и манифеста совпадают с VERSION' do
        parent = File.expand_path('..', File.join(__dir__, '..'))
        registrar = ["#{ID}_dev.rb", "#{ID}.rb"].map { |n| File.join(parent, n) }.find { |p| File.file?(p) }
        skip('регистратор не найден рядом с папкой расширения') unless registrar

        ver = File.read(registrar, encoding: 'UTF-8')[/\.version\s*=\s*['"]([^'"]+)['"]/, 1]
        assert_equal(VERSION, ver, "версия в #{File.basename(registrar)}")

        manifest_path = File.join(__dir__, '..', '.sketchup_dev.json')
        if File.file?(manifest_path)
          require 'json'
          manifest = JSON.parse(File.read(manifest_path, encoding: 'UTF-8'))
          assert_equal(VERSION, manifest['version'], 'версия в .sketchup_dev.json')
          assert_equal(ID, manifest['id'], 'id в .sketchup_dev.json')
        end
      end

      test 'модули отвеч на команды' do
        assert(Rotator.respond_to?(:rotate_selected), 'нет Rotator.rotate_selected')
        assert(Rotator.respond_to?(:create_top_side_views), 'нет Rotator.create_top_side_views')
        assert(Rotator.respond_to?(:duplicate_entity), 'нет Rotator.duplicate_entity')
        assert(Rotator.respond_to?(:calculate_gap), 'нет Rotator.calculate_gap')
        assert(Settings.respond_to?(:get_settings), 'нет Settings.get_settings')
        assert(Settings.respond_to?(:save_settings), 'нет Settings.save_settings')
      end

      test 'иконки ресурсов на месте' do
        %w[rotate.svg views.svg].each do |name|
          path = File.join(__dir__, '..', 'resources', name)
          assert(File.file?(path), "нет иконки #{path}")
        end
      end

      test 'настройки читаются кортежем из 5 значений' do
        z, x, make_copy, side, offset = Settings.get_settings
        assert(z.is_a?(Float) && x.is_a?(Float), 'углы должны быть Float')
        assert([true, false].include?(make_copy), 'make_copy должен быть Boolean')
        assert(%w[Справа Слева].include?(side), "неожидаемый вид сбоку: #{side.inspect}")
        assert(!offset.to_s.empty?, 'отступ пуст')
      end

      test 'calculate_gap: проценты от габарита и фиксированные мм' do
        skip('вне SketchUp: нет Geom::BoundingBox') unless defined?(Geom::BoundingBox)

        bounds = Geom::BoundingBox.new
        bounds.add([0, 0, 0])
        bounds.add([100.mm, 50.mm, 20.mm])

        assert_equal(20.mm, Rotator.calculate_gap(bounds, '20%').to_f, '20% от 100мм')
        assert_equal(150.mm, Rotator.calculate_gap(bounds, '150').to_f, 'фиксированные 150мм')
        assert_equal(10.mm, Rotator.calculate_gap(bounds, '1%').to_f, 'проценты не падают ниже 10мм')
      end

      # Живой тест с моделью — выполняется только внутри SketchUp.
      test 'дублирование группы добавляет копию в модель' do
        skip('вне SketchUp: нет активной модели') unless defined?(Sketchup) && Sketchup.active_model

        model = Sketchup.active_model
        before = model.entities.count
        group = model.entities.add_group
        group.entities.add_face([0, 0, 0], [100.mm, 0, 0], [100.mm, 50.mm, 0], [0, 50.mm, 0])
        copy = nil
        begin
          copy = Rotator.duplicate_entity(group)
          assert(copy.valid?, 'дубликат невалиден')
          assert_equal(before + 2, model.entities.count, 'копия не добавлена в модель')
        ensure
          # тест не оставляет следов в модели пользователя
          [copy, group].each do |e|
            e.erase! if e.respond_to?(:valid?) && e.valid?
          end
        end
      end
    end
  end
end
