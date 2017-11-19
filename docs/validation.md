# Validation

For validation purposes is used [accord](https://github.com/neovintage/accord) shard. So this allows to specify custom class validator:

```crystal
class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true},
    contact_id: {type: Int32, null: true}
  )

  validates_with [EnnValidator]
  belongs_to :contact, Contact
end

class EnnValidator < Accord::Validator
  def initialize(context : Passport)
    @context = context
  end

  def call(errors : Accord::ErrorList)
    if @context.enn!.size < 4 && @context.enn![0].downcase == 'a'
      errors.add(:enn, "Invalid enn")
    end
  end
end
```

Also there are several general macroses for declaring validations:

- `validates_with_method(*names)` - accepts method name/names
- `validates_inclusion(field, value)` - checks if `value` includes `@{{field}}`
- `validates_exclusion(field, value)` - checks if `value` excludes `@{{field}}`
- `validates_format(field, format)` - checks if `{{format}}` matches `@{{field}}`
- `validates_length(field, **options)` - check `@{{field}}` size; allowed options are: `:in`, `:is`, `:maximum`, `:minimum`
- `validates_uniqueness(field)` - check if `@{{field.id}}` is unique
- `validates_presence_of(field)` - check if `@{{field.id}}` is not `nil`

Next macrosses accept `allow_blank` key (which is be default is `false`) which describe `null` allowness during validation: `validates_inclucion`, `validates_exclusion`, `validates_format` and `validates_length`. This means that if `allow_blank: true` is passed, validation will pass if field is `nil` or validation condition is satified. In another words - validation will be sciped if field is `nil`. 

Methods `#save!` and `#create!` will raise an exception if at validation fails. `#save` will return true\false representing object saving.

> To manually check validity call `#validate!` before `#valid?`.
