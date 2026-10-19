# frozen_string_literal: true

require 'sketchup.rb'
require 'yaml'

module CustomTools
  module ComponentAddViews
    # Модуль управления параметрами плагина и работы с файлом конфигурации YAML
    module Settings
      CONFIG_FILE = File.join(__dir__, 'settings.yaml')
      DEFAULTS = {
        'make_copy' => true,
        'angle_z' => 35.0,
        'angle_x' => 35.0,
        'side_view' => 'Справа',
        'offset' => '20%',
        'rot180' => false,
        'language' => 'ru',
        'theme' => 'light'
      }.freeze

      # Нормализация UI-предпочтений панели (источник истины — этот файл;
      # localStorage во фронтенде — только кэш для старта без мерцания)
      def self.normalize_language(v)
        v.to_s.strip.downcase == 'en' ? 'en' : 'ru'
      end

      def self.normalize_theme(v)
        v.to_s.strip.downcase == 'dark' ? 'dark' : 'light'
      end

      # Чтение параметров из YAML-файла с безопасными значениями по умолчанию
      # @return [Array] кортеж [угол_z, угол_x, флаг_копирования, вид_сбоку,
      #   отступ, плюс_180_к_Z, язык, тема]. Хвост (язык/тема) добавлен позже —
      #   старые деструктуризации первых 6 значений продолжают работать.
      def self.get_settings
        data = if File.exist?(CONFIG_FILE)
                 raw = File.read(CONFIG_FILE, encoding: 'UTF-8')
                 loaded = YAML.safe_load(raw)
                 loaded.is_a?(Hash) ? loaded.transform_keys(&:to_s) : {}
               else
                 {}
               end

        data = DEFAULTS.merge(data)
        side = data['side_view'].to_s.strip
        side = 'Справа' unless %w[Справа Слева].include?(side)
        offset = data['offset'].to_s.strip
        offset = DEFAULTS['offset'] if offset.empty?

        [
          data['angle_z'].to_s.tr(',', '.').to_f,
          data['angle_x'].to_s.tr(',', '.').to_f,
          data['make_copy'] != false,
          side,
          offset,
          data['rot180'] == true || data['rot180'] == 'true',
          normalize_language(data['language']),
          normalize_theme(data['theme'])
        ]
      rescue StandardError => e
        warn "[ComponentAddViews] Ошибка чтения настроек: #{e.message}"
        [
          DEFAULTS['angle_z'],
          DEFAULTS['angle_x'],
          DEFAULTS['make_copy'],
          DEFAULTS['side_view'],
          DEFAULTS['offset'],
          DEFAULTS['rot180'],
          DEFAULTS['language'],
          DEFAULTS['theme']
        ]
      end

      # Сохранение настроек в YAML-файл. Язык/тема опциональны (nil — сохранить
      # текущие из файла, чтобы вызовы с 6 геометрическими аргументами
      # (show_settings, Preview.save_params) не сбрасывали выбор пользователя.
      # @param [Numeric, String] z угол поворота по Z
      # @param [Numeric, String] x угол поворота по X
      # @param [Boolean] make_copy создавать ли копию слева
      # @param [String] side_view сторона вида сбоку ('Справа' или 'Слева')
      # @param [String, Numeric] offset отступ проекций (% от габарита или мм)
      # @param [Boolean] rot180 добавить 180° к повороту по Z
      # @param [String, nil] language 'ru'/'en' (nil — не менять)
      # @param [String, nil] theme 'light'/'dark' (nil — не менять)
      # @return [void]
      def self.save_settings(z, x, make_copy = true, side_view = 'Справа', offset = '20%', rot180 = false,
                             language = nil, theme = nil)
        z_val = z.to_s.tr(',', '.').to_f
        x_val = x.to_s.tr(',', '.').to_f
        offset_str = offset.to_s.strip
        offset_str = '20%' if offset_str.empty?

        data = {
          'make_copy' => !!make_copy,
          'angle_z' => z_val,
          'angle_x' => x_val,
          'side_view' => (side_view.to_s.strip == 'Слева' ? 'Слева' : 'Справа'),
          'offset' => offset_str,
          'rot180' => (rot180 == true || rot180 == 'true'),
          'language' => language.nil? ? current_stored('language') : normalize_language(language),
          'theme' => theme.nil? ? current_stored('theme') : normalize_theme(theme)
        }
        File.write(CONFIG_FILE, YAML.dump(data), encoding: 'UTF-8')
      rescue StandardError => e
        warn "[ComponentAddViews] Ошибка сохранения настроек: #{e.message}"
      end

      # Текущее хранимое значение ключа (для nil-сохранения без сброса)
      def self.current_stored(key)
        return DEFAULTS[key] unless File.exist?(CONFIG_FILE)

        raw = File.read(CONFIG_FILE, encoding: 'UTF-8')
        loaded = YAML.safe_load(raw)
        return DEFAULTS[key] unless loaded.is_a?(Hash)

        v = loaded[loaded.key?(key) ? key : key.to_sym]
        v.nil? ? DEFAULTS[key] : v
      rescue StandardError
        DEFAULTS[key]
      end
      private_class_method :current_stored

      # Диалоговое окно для интерактивного изменения настроек пользователем
      # @return [void]
      def self.show_settings
        z, x, copy, side, offset, rot180 = get_settings
        prompts = [
          'Создавать копию слева:',
          'Угол Z (сначала):',
          'Угол X (затем):',
          'Вид сбоку (проекция):',
          'Отступ проекций (% или мм):',
          'Плюс 180° к повороту Z:'
        ]
        defaults = [copy ? 'Да' : 'Нет', z, x, side, offset, rot180 ? 'Да' : 'Нет']
        dropdowns = ['Да|Нет', '', '', 'Справа|Слева', '', 'Да|Нет']

        res = UI.inputbox(prompts, defaults, dropdowns, 'Настройки ComponentAddViews')
        return unless res

        save_settings(res[1], res[2], res[0] == 'Да', res[3], res[4], res[5] == 'Да')
      end
    end
  end
end

