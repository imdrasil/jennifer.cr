There are next macroses for defining callbacks:
- `before_save`
- `after_save`
- `before_create`
- `after_create`
- `after_initialize`
- `before_destroy`
- `after_destroy`
- `before_validation`
- `after_validation`

They accept method names.

Raising `::Jennifer::Skip` inside of any before callback stops current action from being processed. 
