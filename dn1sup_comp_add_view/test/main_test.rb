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

      test 'версия регистратора совпадает с VERSION' do
        parent = File.expand_path('..', File.join(__dir__, '..'))
        registrar = File.join(parent, "#{ID}.rb")
        skip('регистратор не найден рядом с папкой расширения') unless File.file?(registrar)

        ver = File.read(registrar, encoding: 'UTF-8')[/\.version\s*=\s*['"]([^'"]+)['"]/, 1]
        assert_equal(VERSION, ver, "версия в #{File.basename(registrar)}")
      end

      test 'модули отвеч на команды' do
        assert(Rotator.respond_to?(:rotate_selected), 'нет Rotator.rotate_selected')
        assert(Rotator.respond_to?(:create_top_side_views), 'нет Rotator.create_top_side_views')
        assert(Rotator.respond_to?(:duplicate_entity), 'нет Rotator.duplicate_entity')
        assert(Rotator.respond_to?(:calculate_gap), 'нет Rotator.calculate_gap')
        assert(Settings.respond_to?(:get_settings), 'нет Settings.get_settings')
        assert(Settings.respond_to?(:save_settings), 'нет Settings.save_settings')
      end

      test 'предпросмотр: API и cancel безопасен без активного предпросмотра' do
        assert(Preview.respond_to?(:update), 'нет Preview.update')
        assert(Preview.respond_to?(:apply), 'нет Preview.apply')
        assert(Preview.respond_to?(:cancel), 'нет Preview.cancel')
        assert(Preview.respond_to?(:refresh), 'нет Preview.refresh')
        assert(Preview.respond_to?(:active?), 'нет Preview.active?')

        # Без выделения/открытой операции cancel обязан отработать без ошибок
        # и вернуть false
        assert_equal(false, Preview.cancel, 'cancel без предпросмотра должен вернуть false')
        assert_equal(false, Preview.active?)
      end

      test 'иконка кнопки панели на месте' do
        path = File.join(__dir__, '..', 'resources', 'panel.svg')
        assert(File.file?(path), "нет иконки #{path}")
      end

      test 'панель: API модуля Panel' do
        assert(Panel.respond_to?(:show), 'нет Panel.show')
        assert(Panel.respond_to?(:selection_info), 'нет Panel.selection_info')
        assert(Panel.respond_to?(:settings_hash), 'нет Panel.settings_hash')
        assert(Panel.respond_to?(:push_selection), 'нет Panel.push_selection')
      end

      # Регрессия SU2026.2: типовые методы наблюдателей удалены
      # (add_selection_observer и т.п.) — attach обязан ставить наблюдателя
      # через единый add_observer и не падать. Тест живой: выполняется внутри
      # SketchUp, вне его уходит в skip.
      test 'панель: attach/detach наблюдателей работают на этой версии API' do
        skip('вне SketchUp: нет активной модели') unless defined?(Sketchup) && Sketchup.active_model

        model = Sketchup.active_model
        can_attach = model.respond_to?(:add_selection_observer) ||
                     model.selection.respond_to?(:add_observer)
        assert(can_attach, 'ни типового (add_selection_observer), ни единого (Selection#add_observer) способа')

        assert_equal(true, Panel.send(:attach_selection_observer),
                     'attach не смог приаттачить наблюдателя выделения')
        Panel.send(:detach_observers)
      end

      # Живой тест: selection_info различает всего выделенное (total) и цели
      # операций — компоненты/группы (targets); на них гейтится кнопка «Применить»
      test 'панель: selection_info считает компоненты и группы целями' do
        skip('вне SketchUp: нет активной модели') unless defined?(Sketchup) && Sketchup.active_model

        model = Sketchup.active_model
        group = model.entities.add_group
        group.entities.add_face([0, 0, 0], [10.mm, 0, 0], [10.mm, 10.mm, 0], [0, 10.mm, 0])
        begin
          model.selection.add(group)
          info = Panel.selection_info
          assert(info[:total] >= 1, 'total не учитывает выделенную группу')
          assert(info[:targets] >= 1, 'targets не видит группу — кнопки панели останутся неактивными')
        ensure
          model.selection.clear
          group.erase! if group.valid?
        end
      end

      test 'панель: settings_hash содержит ключи интерфейса' do
        h = Panel.settings_hash
        %i[angle_z angle_x make_copy side_view offset version].each do |k|
          assert(h.key?(k), "нет ключа #{k}")
        end
      end

      test 'панель: resources/panel.html собран и содержит корень Vue' do
        html = File.join(__dir__, '..', 'resources', 'panel.html')
        assert(File.file?(html), "нет собранной панели #{html}")
        content = File.read(html, encoding: 'UTF-8')
        assert(content.include?('id="app"'), 'panel.html без корня монтирования Vue (#app)')
        assert(content.bytesize > 50_000, 'panel.html подозрительно мал — бандл не встроен')
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
