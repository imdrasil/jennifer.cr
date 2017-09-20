For validation purposes is used [accord](https://github.com/neovintage/accord) shard. Also there are several general macroses for declaring validations:

- `validates_with_method(*names)` - accepts method name/names
- `validates_inclusion(field, value)` - checks if `value` includes `@{{field}}`
- `validates_exclusion(field, value)` - checks if `value` excludes `@{{field}}`
- `validates_format(field, format)` - checks if `{{format}}` matches `@{{field}}`
- `validates_length(field, **options)` - check `@{{field}}` size; allowed options are: `:in`, `:is`, `:maximum`, `:minimum`
- `validates_uniqueness(field)` - check if `@{{field}}` is unique

Methods `#save!` and `#create!` will raise an exception if at validation fails. `#save` will return true\false representing object saving.
