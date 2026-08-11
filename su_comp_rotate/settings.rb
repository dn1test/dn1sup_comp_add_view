# frozen_string_literal: true

require 'sketchup.rb'
require 'yaml'

module CustomTools
  module ComponentRotator
    module Settings
      CONFIG_FILE = File.join(__dir__, 'settings.yaml')

      DEFAULT_SETTINGS = {
        'make_copy' => true,
        'angle_z'   => 0.0,
        'angle_x'   => 0.0
      }.freeze

      # Путь к конфигурационному файлу
      # @return [String]
      def self.config_file_path
        CONFIG_FILE
      end

      # Безопасная загрузка данных из YAML
      # @return [Hash]
      def self.load_data
        return DEFAULT_SETTINGS.dup unless File.exist?(CONFIG_FILE)

        content = File.read(CONFIG_FILE, encoding: 'UTF-8')
        data = YAML.safe_load(content)
        data.is_a?(Hash) ? data : DEFAULT_SETTINGS.dup
      rescue StandardError => e
        warn "[ComponentRotator] Ошибка загрузки #{CONFIG_FILE}: #{e.message}. Применяются значения по умолчанию."
        DEFAULT_SETTINGS.dup
      end

      # Получение текущих сохраненных параметров
      # @return [Array(Float, Float, Boolean)] [angle_z, angle_x, make_copy]
      def self.get_settings
        data = load_data

        raw_copy = data.key?('make_copy') ? data['make_copy'] : data[:make_copy]
        raw_z = data.key?('angle_z') ? data['angle_z'] : data[:angle_z]
        raw_x = data.key?('angle_x') ? data['angle_x'] : data[:angle_x]

        make_copy = case raw_copy
                    when TrueClass, FalseClass then raw_copy
                    when String then raw_copy.strip.downcase != 'false'
                    when Numeric then raw_copy != 0
                    when nil then DEFAULT_SETTINGS['make_copy']
                    else true
                    end

        angle_z = raw_z.nil? ? DEFAULT_SETTINGS['angle_z'] : raw_z.to_f
        angle_x = raw_x.nil? ? DEFAULT_SETTINGS['angle_x'] : raw_x.to_f

        [angle_z, angle_x, make_copy]
      end

      # Сохранение параметров в YAML-файл
      # @param [Numeric] z
      # @param [Numeric] x
      # @param [Boolean] make_copy
      def self.save_settings(z, x, make_copy = true)
        data = {
          'make_copy' => make_copy ? true : false,
          'angle_z'   => z.to_f,
          'angle_x'   => x.to_f
        }

        File.open(CONFIG_FILE, 'w:UTF-8') do |f|
          f.puts '# Настройки расширения Component Rotator'
          f.write(YAML.dump(data).sub(/\A---\s*\n/, ''))
        end

        data
      rescue StandardError => e
        warn "[ComponentRotator] Ошибка сохранения #{CONFIG_FILE}: #{e.message}"
      end

      # Окно настройки параметров
      def self.show_settings
        current_z, current_x, current_copy = get_settings

        prompts = ['Создавать копию слева:', 'Угол Z (сначала):', 'Угол X (затем):']
        defaults = [current_copy ? 'Да' : 'Нет', current_z, current_x]
        list = ['Да|Нет', '', '']

        results = UI.inputbox(prompts, defaults, list, 'Настройки поворота (Z -> X)')
        return unless results

        make_copy = (results[0].to_s == 'Да')
        angle_z = results[1].to_f
        angle_x = results[2].to_f

        save_settings(angle_z, angle_x, make_copy)
        puts "Новые настройки сохранены: Копия=#{make_copy}, Z=#{angle_z}, X=#{angle_x}"
      end
    end
  end
end
