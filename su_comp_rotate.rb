# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module CustomTools
  module ComponentAddViews
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new(
        'ComponentAddViews',
        File.join('su_comp_rotate', 'main')
      )
      extension.description = 'Создает копии компонентов и групп слева, поворачивает по осям Z и X, а также создает проекции вида сверху и сбоку.'
      extension.version     = '1.1.0'
      extension.creator     = 'dn1codegen@gmail.com'
      extension.copyright   = 'DN1 2026 - dn1codegen'

      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end