# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module CustomTools
  module ComponentRotator
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new(
        'ComponentRotator',
        File.join('su_comp_rotate', 'main')
      )
      extension.description = 'Создает копию компонента или группы слева и поворачивает её по осям Z и X.'
      extension.version     = '1.0.0'
      extension.creator     = 'dn1codegen@gmail.com'
      extension.copyright   = 'DN1 2026 - dn1codegen'

      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end