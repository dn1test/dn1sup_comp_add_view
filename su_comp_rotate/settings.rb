# frozen_string_literal: true

require 'sketchup.rb'

module CustomTools
  module ComponentRotator
    module Settings
      # Ключ реестра для сохранения параметров
      REGISTRY_KEY = 'CustomTools_ComponentRotator'

      # Получение текущих сохраненных параметров
      # @return [Array(Float, Float, Boolean)] [angle_z, angle_x, make_copy]
      def self.get_settings
        z = Sketchup.read_default(REGISTRY_KEY, 'angle_z', 0.0).to_f
        x = Sketchup.read_default(REGISTRY_KEY, 'angle_x', 0.0).to_f

        raw_copy = Sketchup.read_default(REGISTRY_KEY, 'make_copy', true)
        make_copy = case raw_copy
                    when TrueClass, FalseClass then raw_copy
                    when String then raw_copy.strip.downcase != 'false'
                    when Numeric then raw_copy != 0
                    else true
                    end

        [z, x, make_copy]
      end

      # Сохранение параметров
      # @param [Numeric] z
      # @param [Numeric] x
      # @param [Boolean] make_copy
      def self.save_settings(z, x, make_copy = true)
        Sketchup.write_default(REGISTRY_KEY, 'angle_z', z.to_f)
        Sketchup.write_default(REGISTRY_KEY, 'angle_x', x.to_f)
        Sketchup.write_default(REGISTRY_KEY, 'make_copy', make_copy ? true : false)
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
