# Validation

Here is an example of validation usage:

```crystal
class User < Jennifer::Model::Base
  mapping({
    # ...
    login: String
  })

  validates_length :login, in: 8..16
end
```

```crystal
User.create({login: "login"}).valid? # => false
User.create({login: "loginlogin"}).valid? # => true
```

As you can see, our validation lets us know that our `User` is not valid with a too short login attribute. Once we set long enough value `User` will not be persisted to the database.

## Trigger validation

The following model methods triggers validations in a scope of own execution:

- `.create`
- `.create!`
- `#validate`
- `#validate!`
- `#valid?`
- `#save`
- `#save_without_transaction`
- `#save!`
- `#update`
- `#update!`

> NOTE: Bang method version will raise an exception if record is invalid.
>
> NOTE: `#valid?` is an alias for `#validate!`.
>
> `Jennifer::Query#patch` also invokes validation (and callbacks) for each matched record.

`#validate!` method invokes validation callbacks. Be aware: `after_validation` callbacks may not be triggered if record is invalid or `before_validation` has raised `Jennifer::Skip` exception.

## Skip validation

Some methods skip validation on invocation:

- `Model::Base#invalid?`
- `Model::Base#save(skip_validation: true)`
- `Model::Base#update_column`
- `Model::Base#update_columns`
- `QueryBuilder::Query#update`
- `QueryBuilder::Query#increment`
- `QueryBuilder::Query#decrement`

> NOTE: `#invalid?` method will only check if `#errors` is empty.

## Validation macros

Please take into account that all validators described below implement singleton pattern - there is only one instance of each of them in application.

### `validates_acceptance`

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

### `validates_confirmation`

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

### `validates_exclusion`

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

### `validates_format`

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

### `validates_inclusion`

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

### `validates_length`

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

### `validates_numericality`

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

### `validates_presence`

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

### `validates_absence`

This validates that attribute's value is blank. It uses `#blank?` method from Ifrit as well as `presence` validation.

```crystal
class SuperUser < User
  mapping(
    # ...
  )

  validates_absence :title
end
```

### `validates_uniqueness`

This validates that the attribute's value is unique right before object gets validated. It doesn't create any db constraint so it doesn't totally guaranty that another another application instance creates record with save value in overlapping time. **Don't use** this validation for sensitive data. On the other hand this could help in generating readable error messages.

```crystal
class Country < Jennifer::Model::Base
  mapping(
    # ...
    code: String
  )

  validates_uniqueness :code
end
```

> NOTE: Be aware that mysql performs case insensitive string comparison.

### `validates_with`

This passes the record to a new instance of given validator class to be validated.

```crystal
class EnnValidator < Jennifer::Validations::Validator
  def validate(record, **opts)
    if record.enn!.size < 4 && record.enn![0].downcase == 'a'
      record.errors.add(:enn, "Invalid enn")
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

### `if` validation option

Sometimes it will make sense to validate an object only when a given predicate is satisfied. You can do that by using the :if option, which can take a symbol or an expression. You may use the :if option when you want to specify when the validation should happen.

The symbol value of :if options corresponds to the method name that will get called right before validation happens.

```crystal
class Player < Jennifer::Model::Base
  mapping(
    # ...
    health: Float64,
    live_creature: {type: Bool, default: true, virtual: true}
  )

  validates_numericality :health, greater_than: 0, if: :live_creature
end
```

An expression may be used to simulate *unless* behavior of simple condition without wrapping it into a method.

```crystal
class Player < Jennifer::Model::Base
  mapping(
    # ...
    health: Float64,
    undead: {type: Bool, default: false, virtual: true}
  )

  validates_numericality :health, greater_than: 0, if: !undead
end
```

## Common validation options

These are common validation options:

### `allow_blank`

This option skip validation if attribute's value is `nil`. All validation methods accepts this except following:

- `uniqueness`
- `presence`
- `absence`
- `acceptance`
- `confirmation`

By default it is set to `false`.

### `if`

Sometimes it will make sense to validate an object only when a given predicate is satisfied. You can do that by using the :if option, which can take a symbol or an expression. You may use the :if option when you want to specify when the validation should happen.

The symbol value of :if options corresponds to the method name that will get called right before validation happens.

```crystal
class Player < Jennifer::Model::Base
  mapping(
    # ...
    health: Float64,
    live_creature: {type: Bool, default: true, virtual: true}
  )

  validates_numericality :health, greater_than: 0, if: :live_creature
end
```

An expression may be used to simulate *unless* behavior of simple condition without wrapping it into a method.

```crystal
class Player < Jennifer::Model::Base
  mapping(
    # ...
    health: Float64,
    undead: {type: Bool, default: false, virtual: true}
  )

  validates_numericality :health, greater_than: 0, if: !undead
end
```

### `message`

the `message` option lets you specify the message that will be added to the errors collection when validation fails. When this option is not used,respective default error message for each validation is used. The `message` option accepts a `String`, `Symbol` or `Proc`.

A `String` `message` value is used as a validation error message as-is.

A `Proc` `message` value is given two arguments: the object being validated and a field name.

A `Symbol` `message` is used as a message name and Jennifer will try to find it for model-attribute combination using default message resolving hierarchy. For more information about this read [Internationalization](./internationalization.md) section.

```crystal
class Person < Jennifer::Model::Base
  mapping(
    id: Primary64,
    name: String?,
    age: Int32?,
    username: String?
  )

  # Hard-coded message
  validates_presence :name, message: "must be given please"

  # Message i18n name.
  validates_numericality :age, greater_than: 18, message: :invalid

  # Proc
  validates_uniqueness :username,
    message: ->(object : Jennifer::Model::Translation, field : String) do
      record = object.as(Person)
      "Hey #{record.name}, #{record.attribute(field)} is already taken."
    end
end
```

## Custom validation

### Custom validators

Custom validators are classes that inherit from `Jennifer::Validations::Validator` and implement `#validate` method.

```crystal
class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true}
  )

  validates_with EnnValidator
end

class EnnValidator < Jennifer::Validations::Validator
  def validate(record)
    if record.enn!.size < 4 && record.enn![0].downcase == 'a'
      record.errors.add(:enn, "Invalid enn")
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
  def validate(record, length)
    if record.enn!.size < length && record.enn![0].downcase == 'a'
      record.errors.add(:enn, "Invalid enn")
    end
  end
end
```

To override default singleton behavior of validator define `.instance` method this way:

```crystal
class CustomValidator < Jennifer::Validations::Validator
  def self.instance
    new
  end

  def validate(record)
  end
end
```

## Accessing errors list

Each record has a container to hold error messages - `Accord::ErrorList`. To retrieve it use `#errors` method.

By it own `#errors` doesn't trigger validation so first of all you need to perform it explicitly by listed upper methods or using `#validate!` method:

```crystal
user = User.new(login: "login")
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

### Non-model usage

It is possible to use `Jennifer::Model::Errors` for handling errors of any class that includes `Jennifer::Model::Translation` and implements `.superclass` method.

```crystal
class Post
  include Jennifer::Model::Translation

  property title : String?
  getter errors

  def initialize
    @errors = Jennifer::Model::Errors.new(self)
  end

  def validate
    errors.clear
    errors.add(:title, :blank) if title.nil?
  end

  # The following method is needed to be minimally implemented

  def self.superclass; end
end

post = Post.new
post.validate
post.errors[:title] # "can't be blank"
```
