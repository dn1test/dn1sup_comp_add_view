# frozen_string_literal: true

# Author: DN1Sup <dn1codegen@gmail.com>
# License: MIT

require 'sketchup.rb'
require 'extensions.rb'

module CustomTools
  module ComponentAddViews
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new(
        'DN1Sup Component Add View',
        File.join('dn1sup_comp_add_view', 'main')
      )
      extension.description = 'Создает копии компонентов и групп слева, поворачивает по осям Z и X, а также создает проекции вида сверху и сбоку.'
      extension.version     = '0.4.2'
      extension.creator     = 'DN1Sup'
      extension.copyright   = '2026 DN1Sup <dn1codegen@gmail.com> (MIT)'
      extension.id          = 'dn1sup_comp_add_view' if extension.respond_to?(:id=)

      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end