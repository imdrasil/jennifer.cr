# Validation

Here is an example of validation usage:

```crystal
class User < Jennifer::Model::Base
  mapping({
    # ...
    login: String
  })

  validates_length :login, in: [8..16]
end

user = User.build(login: "login")
user.validate!
user.valid? # false
user.login = "longlogin"
user.validate!
user.valid? # true
```

## Trigger validation

The following methods triggers validations and will save the object only if all validations will pass:

- validate
- validate!
- valid?
- create
- create!
- save
- save_without_transaction
- save!
- update
- update!

> NOTE: Bang method version will raise an exception if record is invalid.
>
> NOTE: `#valid?` is an alias for `#validate!`.

`#validate!` method will also invoke validation callbacks. Be aware: `after_validation` callbacks may not be triggered if record is invalid or `before_validation` has raised `Jennifer::Skip` exception.

## Skip validation

Not all methods which hit db perform validation. They are:

- invalid?
- save(skip_validation: true)
- update_column
- update_columns
- modify
- increment
- decrement

> NOTE: `#invalid?` method will only check if `#errors` is empty.

## Accessing errors list

Each record has a container to hold error messages - `Accord::ErrorList`. To retrieve it use `#errors` method.

By it own `#errors` doesn't trigger validation so first of all you need to perform it explicitly by listed upper methods or using `#validate!` method:

```crystal
user = User.build(login: "login")
user.errors.any? # false
user.validate!
user.errors.any? # true
```

### `errors[]`

To check whether or not a particular attribute of an object is valid you can use  `#errors[:attribute]`. It returns an array of error messages for `:attribute`. If there is no error - empty array will be returned.

### `#errors.add`

This methods let you add an error message related to a particular attribute. It takes as arguments tre attribute and the error message.

```crystal
user = User.create(login: "login")
user.errors.add(:login, "Some custom message")
```

### `errors.clear!`

The `#clear!` method is used when all error messages should be removed. It is automatically invoked by `#validate!`.

## Validation macros

### `acceptance`

This macro validates that a given field equals to true or be one of given values. This is useful for validating checkbox value:

```crystal
class User < Jennifer::Model::Base
  mapping(
    # ...
  )

  property terms_of_service = false
  property eula : String?

  validates_acceptance :terms_of_service
  validates_acceptance :eula, accept: %w(true accept yes)
end
```

By default `"1"` and `true` is recognized as accepted values, but, as described, this behavior could be override by passing `accept` option with array.

### `confirmation`

This validation helps to check if confirmation field was filled with same value as specified.

```crystal
class User < Jennifer::Model::Base
  mapping(
    # ...
    email: String?,
    address: String?
  )

  property email_confirmation : String?, address_confirmation : String?

  validates_confirmation :email
  validates_confirmation :address, case_insensitive: true
end
```

If confirmation is nil - this validation will be skipped. Such behavior allows to normally proceed in places where this validation is not needed (e.g. email confirmation is important only during new user creating).

To make comparison case insensitive - specify second argument as `true`.

### `exclusion`

This macro validates that the attribute's value aren't included in a given set. This could be any object which responds to `#includes?` method.

```crystal
class Country < Jennifer::Base::Model
  mapping(
    # ...
    code: String
  )

  validates_exclusion :code, in: %w(AA DD)
end
```

### `format`

This macro validates that the attribute's value satisfies given regular expression.

```crystal
class Contact < Jennifer::Model::Base
  mapping(
    # ...
    street: String
  )

  validates_format :street, /st\.|street/i
end
```

### `inclusion`

This macro validates that the attribute's value are included in the set. This could be any object which responds to `#includes?` method.

```crystal
class User < Jennifer::Base::Model
  mapping(
    # ...
    country_code: String
  )

  validates_inclusion :code, in: Country::KNOWN_COUNTRIES
end
```

### `length`

This macro validates the attribute's value length. There are a lot of options so constraint can be specified in different ways.

```crystal
class User < Jennifer::Model::Base
  mapping(
    # ...
  )

  validates_length :name, minimum: 2
  validates_length :login, in: 4..16
  validates_length :uid, is: 16
end
```

The possible constraints are:

- `minimum` - length can't be less than specified one,
- `maximum` - length can't be greater than specified on,
- `in` - length must be included in given **interval**
- `is` - length must be same as specified

### `numericality`

This macro validates if given number field satisfies specified constraints.

``` crystal
class Player < Jennifer::Model::Base
  mapping(
    # ...
    points: Float64?
  )

  validates_numericality :points, greater_than: 0
end
```

This macro accepts following constraints:

- `greater_than`
- `greater_than_or_equal_to`
- `equal_to`
- `less_than`
- `less_than_or_equal_to`
- `other_than`
- `odd`
- `even`

### `presence_of`

This macro validates that attribute's value is not empty. It uses `#blank?` method from the core pact of [Ifrit](https://github.com/imdrasil/ifrit#core).

```crystal
class User < Jennifer::Model::Base
  mapping(
    # ...
    email: String?
  )

  validates_presence :email
end
```

### `absence`

This validates that attribute's value is blank. It uses `#blank?` method from Ifrit as well as `presence` validation.

```crystal
class SuperUser < User
  validates_absence :title
end
```

### `uniqueness`

This validates that the attribute's value is unique right before object gets validated. It doesn't create any db constraint so it doesn't totally guaranty that another another application instance creates record with save value in overlapping time. **Don't use** this validation for sensitive data. On the other hand this could help in generating readable error messages.

```crystal
class Country < Jennifer::Model::Base
  mapping(
    # ...
    code: String
  )

  validate_uniqueness :code
end
```

> NOTE: Be aware that mysql performs case insensitive string comparison.

### `validates_with`

This passes the record to a new instance of given validator class to be validated.

```crystal
class EnnValidator < Jennifer::Validator
  def validate(subject : Passport)
    if subject.enn!.size < 4 && subject.enn![0].downcase == 'a'
      errors.add(:enn, "Invalid enn")
    end
  end
end

class Passport < Jennifer::Model::Base
  mapping(
    # ...
    enn: {type: String, primary: true}
  )

  validates_with EnnValidator
end
```

### `validates_with_method`

This invokes specified record method to perform validation

```crystal
class User < Jennifer::Model::Base
  mapping(
    id: Primary?
  )

  validates_with_method :thirteen

  def thirteen
    if id == 13
      errors.add(:id, "Can't be 13")
    end
  end
end
```

### `allow_blank` validation option

This option skip validation if attribute's value is `nil`. All validation methods accepts this except:

- `uniqueness`
- `presence`
- `absence`
- `acceptance`
- `confirmation`

By default it is set to `false`.

## Custom validation

### Custom validators

Custom validators are classes that inherit from `Jennifer::Validator` and implement `#validate` method.

```crystal
class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true}
  )

  validates_with EnnValidator
end

class EnnValidator < Jennifer::Validator
  def validate(subject)
    if subject.enn!.size < 4 && subject.enn![0].downcase == 'a'
      errors.add(:enn, "Invalid enn")
    end
  end
end
```

If there is any named argument specified after validator class - it will be passed to `#validate` method as well.

```crystal
class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true}
  )

  validates_with EnnValidator, length: 6
end

class EnnValidator < Jennifer::Validator
  def validate(subject, length)
    if subject.enn!.size < length && subject.enn![0].downcase == 'a'
      errors.add(:enn, "Invalid enn")
    end
  end
end
```
