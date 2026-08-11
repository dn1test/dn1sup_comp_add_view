# frozen_string_literal: true

require 'sketchup.rb'

module CustomTools
  module ComponentRotator
    module Settings
      # Ключ реестра для сохранения параметров
      REGISTRY_KEY = 'CustomTools_ComponentRotator'

      # Получение текущих сохраненных углов
      # @return [Array<Float>] [angle_z, angle_x]
      def self.get_settings
        z = Sketchup.read_default(REGISTRY_KEY, 'angle_z', 0.0).to_f
        x = Sketchup.read_default(REGISTRY_KEY, 'angle_x', 0.0).to_f
        [z, x]
      end

      # Сохранение углов
      # @param [Numeric] z
      # @param [Numeric] x
      def self.save_settings(z, x)
        Sketchup.write_default(REGISTRY_KEY, 'angle_z', z.to_f)
        Sketchup.write_default(REGISTRY_KEY, 'angle_x', x.to_f)
      end

      # Окно настройки параметров
      def self.show_settings
        current_z, current_x = get_settings

        prompts = ['Угол Z (сначала):', 'Угол X (затем):']
        defaults = [current_z, current_x]

        results = UI.inputbox(prompts, defaults, 'Настройки поворота (Z -> X)')
        return unless results

        save_settings(results[0], results[1])
        puts "Новые углы по умолчанию сохранены: Z=#{results[0]}, X=#{results[1]}"
      end
    end
  end
end
