# frozen_string_literal: true

require 'sketchup.rb'
require 'yaml'

module CustomTools
  module ComponentRotator
    # Модуль управления параметрами плагина и работы с файлом конфигурации YAML
    module Settings
      CONFIG_FILE = File.join(__dir__, 'settings.yaml')
      DEFAULTS = { 'make_copy' => true, 'angle_z' => 0.0, 'angle_x' => 0.0 }.freeze

      # Чтение параметров из YAML-файла с безопасными значениями по умолчанию
      # @return [Array(Float, Float, Boolean)] кортеж [угол_z, угол_x, флаг_копирования]
      def self.get_settings
        data = File.exist?(CONFIG_FILE) ? YAML.safe_load(File.read(CONFIG_FILE, encoding: 'UTF-8')) : {}
        data = DEFAULTS.merge(data.is_a?(Hash) ? data : {})
        [data['angle_z'].to_f, data['angle_x'].to_f, data['make_copy'] != false]
      rescue StandardError => e
        warn "[ComponentRotator] Ошибка чтения настроек: #{e.message}"
        [DEFAULTS['angle_z'], DEFAULTS['angle_x'], DEFAULTS['make_copy']]
      end

      # Сохранение настроек в YAML-файл
      # @param [Numeric] z угол поворота по Z
      # @param [Numeric] x угол поворота по X
      # @param [Boolean] make_copy создавать ли копию слева
      # @return [void]
      def self.save_settings(z, x, make_copy = true)
        data = { 'make_copy' => !!make_copy, 'angle_z' => z.to_f, 'angle_x' => x.to_f }
        File.write(CONFIG_FILE, YAML.dump(data), encoding: 'UTF-8')
      rescue StandardError => e
        warn "[ComponentRotator] Ошибка сохранения настроек: #{e.message}"
      end

      # Диалоговое окно для интерактивного изменения настроек пользователем
      # @return [void]
      def self.show_settings
        z, x, copy = get_settings
        prompts = ['Создавать копию слева:', 'Угол Z (сначала):', 'Угол X (затем):']
        defaults = [copy ? 'Да' : 'Нет', z, x]
        dropdowns = ['Да|Нет', '', '']

        res = UI.inputbox(prompts, defaults, dropdowns, 'Настройки поворота (Z -> X)')
        return unless res

        save_settings(res[1], res[2], res[0] == 'Да')
      end
    end
  end
end
