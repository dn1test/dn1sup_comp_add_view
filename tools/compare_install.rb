# frozen_string_literal: true

# Сравнение установленной копии расширения в Plugins с текущей версией репозитория.
# Запуск: ruby tools/compare_install.rb

PLUGINS = 'C:/Users/dn1desn/AppData/Roaming/SketchUp/SketchUp 2025/SketchUp/Plugins'
REPO = File.expand_path('..', __dir__)

def ver(text)
  text[/extension\.version\s*=\s*'([^']+)'/, 1] || text[/VERSION\s+=\s*'([^']+)'/, 1]
end

puts '== Установлено в Plugins =='
reg = File.read(File.join(PLUGINS, 'dn1sup_comp_add_view.rb'), encoding: 'UTF-8')
puts "registrar version: #{ver(reg)}"
main = File.read(File.join(PLUGINS, 'dn1sup_comp_add_view', 'main.rb'), encoding: 'UTF-8')
puts "main.rb VERSION:   #{ver(main)}"
%w[preview.rb dialog.rb main.rb].each do |f|
  n = File.read(File.join(PLUGINS, 'dn1sup_comp_add_view', f)).scan('apply_many').size
  puts "apply_many in #{f}: #{n}"
end
panel = File.read(File.join(PLUGINS, 'dn1sup_comp_add_view', 'resources', 'panel.html'), encoding: 'UTF-8')
puts "panel.html bytes:  #{panel.bytesize}"
puts "panel.html preview_apply_many: #{panel.scan('preview_apply_many').size}"
puts "panel.html scheme aria: #{panel.include?('Схема поворота и проекций')}"

puts
puts '== Репозиторий (рабочая копия) =='
reg2 = File.read(File.join(REPO, 'dn1sup_comp_add_view.rb'), encoding: 'UTF-8')
puts "registrar version: #{ver(reg2)}"
main2 = File.read(File.join(REPO, 'dn1sup_comp_add_view', 'main.rb'), encoding: 'UTF-8')
puts "main.rb VERSION:   #{ver(main2)}"
%w[preview.rb dialog.rb main.rb].each do |f|
  n = File.read(File.join(REPO, 'dn1sup_comp_add_view', f)).scan('apply_many').size
  puts "apply_many in #{f}: #{n}"
end
panel2 = File.read(File.join(REPO, 'dn1sup_comp_add_view', 'resources', 'panel.html'), encoding: 'UTF-8')
puts "panel.html bytes:  #{panel2.bytesize}"
puts "panel.html preview_apply_many: #{panel2.scan('preview_apply_many').size}"
puts "panel.html scheme aria: #{panel2.include?('Схема поворота и проекций')}"
