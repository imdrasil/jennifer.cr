# Callbacks

During the normal operation of your application, objects may be created, updated, and destroyed. Jennifer provides hooks into this object life cycle so that you can control your application and its data.

Callbacks allow you to trigger logic before or after an alteration of an object's state.

## Callbacks overview

### Registration

In order to use available callbacks, you need to define them. To do this implement callback as instance method and use macro to register it as callback:

```crystal
class User < Jennifer::Base::Model
  mapping(
    id: Primary64,
    email: String
  )

  before_validation :clean_up_email

  private def clean_up_email
    self.email = email.gsub('+', "")
  end
end
```

## Available callbacks

Here is a list with all the available callbacks, listed in the same order in which they will get called during the respective operations:

### Creating new object

- `before_validation`
- `after_validation`
- `before_save`
- `before_create`
- `after_create`
- `after_save`
- `after_commit` / `after_rollback`

### Updating existing object

- `before_validation`
- `after_validation`
- `before_save`
- `before_update`
- `after_update`
- `after_save`
- `after_commit` / `after_rollback`

### Destroying an object

- `before_destroy`
- `after_destroy`
- `after_commit` / `after_rollback`

## Invoking callbacks

The following methods trigger callbacks:

- validate!
- valid?
- create
- create!
- destroy
- destroy_without_transaction
- save
- save!
- save_without_transaction
- update
- update!

The `after_initialize` callback is triggered each time record is initialized using method `.new`.

## Skipping callbacks

The following methods allows to skip some callbacks or process without them:

- validate
- invalid?
- save(skip_validation: true)
- destroy_without_transaction (no transaction callback will be triggered)
- save_without_transaction (no transaction callback will be triggered)
- update_column
- update_columns
- delete
- modify
- increment
- decrement

Carefully use this methods because otherwise you might get invalid data in a db.

## Stopping execution

Raising `::Jennifer::Skip` exception inside of any callback will stop further callback invoking; such behavior in the any `before` callback stops current action from being processed.

## Transaction callbacks

There are 2 additional callbacks that are triggered right after database transaction completion: `after_commit` and `after_rollback`. The main difference of these callbacks is they will be executed only after top level transaction will be completed (committed or rolled back) - instead invoking just in place. Also they expect context to be invoked on: create, save, update or destroy. E.g.:

```crystal
class User < Jennifer::Model::Base
  mapping(
    id: Primary64,
    name: String
  )
  after_save :saved
  after_commit :committed, on: :save

  def saved
    puts "saved"
  end

  def committed
    puts "committed"
  end
end

user = User.all.first!

User.transaction do
  user.name = "new name"
  user.save
  puts "end of transaction"
end
puts "after transaction"
```

will ends with next output:

```text
saved
end of transaction
committed
after transaction
```
