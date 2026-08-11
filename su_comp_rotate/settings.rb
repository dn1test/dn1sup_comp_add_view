# frozen_string_literal: true

require 'sketchup.rb'
require 'yaml'

module CustomTools
  module ComponentAddViews
    # Модуль управления параметрами плагина и работы с файлом конфигурации YAML
    module Settings
      CONFIG_FILE = File.join(__dir__, 'settings.yaml')
      DEFAULTS = { 'make_copy' => true, 'angle_z' => 0.0, 'angle_x' => 0.0, 'side_view' => 'Справа', 'offset' => '20%' }.freeze

      # Чтение параметров из YAML-файла с безопасными значениями по умолчанию
      # @return [Array(Float, Float, Boolean, String, String)] кортеж [угол_z, угол_x, флаг_копирования, вид_сбоку, отступ]
      def self.get_settings
        data = File.exist?(CONFIG_FILE) ? YAML.safe_load(File.read(CONFIG_FILE, encoding: 'UTF-8')) : {}
        data = DEFAULTS.merge(data.is_a?(Hash) ? data : {})
        side = data['side_view'].to_s.strip
        side = 'Справа' unless %w[Справа Слева].include?(side)
        offset = data['offset'].to_s.strip
        offset = DEFAULTS['offset'] if offset.empty?
        [data['angle_z'].to_f, data['angle_x'].to_f, data['make_copy'] != false, side, offset]
      rescue StandardError => e
        warn "[ComponentAddViews] Ошибка чтения настроек: #{e.message}"
        [DEFAULTS['angle_z'], DEFAULTS['angle_x'], DEFAULTS['make_copy'], DEFAULTS['side_view'], DEFAULTS['offset']]
      end

      # Сохранение настроек в YAML-файл
      # @param [Numeric] z угол поворота по Z
      # @param [Numeric] x угол поворота по X
      # @param [Boolean] make_copy создавать ли копию слева
      # @param [String] side_view сторона вида сбоку ('Справа' или 'Слева')
      # @param [String, Numeric] offset отступ проекций (% от габарита или мм)
      # @return [void]
      def self.save_settings(z, x, make_copy = true, side_view = 'Справа', offset = '20%')
        offset_str = offset.to_s.strip
        offset_str = '20%' if offset_str.empty?

        data = {
          'make_copy' => !!make_copy,
          'angle_z' => z.to_f,
          'angle_x' => x.to_f,
          'side_view' => (side_view.to_s.strip == 'Слева' ? 'Слева' : 'Справа'),
          'offset' => offset_str
        }
        File.write(CONFIG_FILE, YAML.dump(data), encoding: 'UTF-8')
      rescue StandardError => e
        warn "[ComponentAddViews] Ошибка сохранения настроек: #{e.message}"
      end

      # Диалоговое окно для интерактивного изменения настроек пользователем
      # @return [void]
      def self.show_settings
        z, x, copy, side, offset = get_settings
        prompts = [
          'Создавать копию слева:',
          'Угол Z (сначала):',
          'Угол X (затем):',
          'Вид сбоку (проекция):',
          'Отступ проекций (% или мм):'
        ]
        defaults = [copy ? 'Да' : 'Нет', z, x, side, offset]
        dropdowns = ['Да|Нет', '', '', 'Справа|Слева', '']

        res = UI.inputbox(prompts, defaults, dropdowns, 'Настройки ComponentAddViews')
        return unless res

        save_settings(res[1], res[2], res[0] == 'Да', res[3], res[4])
      end
    end
  end
end

