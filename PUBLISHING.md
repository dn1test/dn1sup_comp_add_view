# Публикация расширения на GitHub

> Полная общая инструкция — мастер `U:\dn1code\sketchup_ext\PUBLISHING.md`
> (единственная полная копия: как Store ищет репозитории, обязательные
> требования, registry.json, версии и changelog, релизы). Ниже — локальный
> чек-лист этого репозитория.

## Чек-лист этого репозитория

| Требование | Статус |
|---|---|
| Имя `dn1sup_*` в аккаунте `dn1test` | ✅ `dn1test/dn1sup_comp_add_view` |
| Не archived | ✅ |
| `registry.json` в корне `main` | ✅ (id, name, description, version 0.9.0) |
| Стабильные релизы с `.rbz` | ✅ `dist/…rbz` через CI |
| Теги `vMAJOR.MINOR.PATCH` | ✅ (workflow на `v*`) |
| Регистратор `<id>.rb` + `ext.id` | ✅ `dn1sup_comp_add_view.rb` в корне репозитория (раньше назывался `su_component_add_view.rb` и переименовывался при сборке — теперь имена совпадают с `<id>` везде) |
