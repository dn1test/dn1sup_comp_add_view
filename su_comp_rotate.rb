# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module CustomTools
  module ComponentRotator
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new(
        'Копия слева и Поворот Z-X',
        File.join('su_comp_rotate', 'main')
      )
      extension.description = 'Создает копию компонента или группы слева и поворачивает её по осям Z и X.'
      extension.version     = '1.0.0'
      extension.creator     = 'CustomTools'
      extension.copyright   = '2026'

      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end