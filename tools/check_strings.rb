# frozen_string_literal: true

# Проверка свежести и состава собранной панели (resources/panel.html).
# Запуск: ruby tools/check_strings.rb

panel = File.read(File.join(__dir__, '..', 'dn1sup_comp_add_view', 'resources', 'panel.html'), encoding: 'UTF-8')

checks = {
  'нет старой нижней галки «Виды сверху и сбоку»' => !panel.include?(' Виды сверху и сбоку '),
  'заголовок «Вид сверху и сбоку»' => panel.include?('Вид сверху и сбоку'),
  'кнопка «Применить»' => panel.include?('Применить'),
  'колбэк preview_apply_many' => panel.include?('preview_apply_many'),
  'подсказка «Будут выполнены»' => panel.include?('Будут выполнены'),
  'схема (i18n-подпись «вид сверху (план)»)' => panel.include?('вид сверху (план)'),
  'справка' => panel.include?('Справка'),
  'переключатель темы' => panel.include?('dn1sup_comp_add_view_theme'),
  'переключатель языка' => panel.include?('dn1sup_comp_add_view_lang'),
  'тёмная тема (dark:)' => panel.include?('dark:bg-slate-900')
}

failed = 0
checks.each do |name, ok|
  failed += 1 unless ok
  puts "#{ok ? 'OK  ' : 'FAIL'} #{name}"
end
puts "panel bytes: #{panel.bytesize}"
exit(failed.zero? ? 0 : 1)
