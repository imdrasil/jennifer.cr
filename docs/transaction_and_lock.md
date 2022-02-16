# Transaction & Lock

### Transaction

Transaction mechanism provides block-like syntax:

```crystal
Jennifer::Adapter.default_adapter.transaction do |tx|
  Contact.create({:name => "Chose", :age => 20})
end
```

If any error was raised in block transaction will be rollbacked. To rollback transaction raise `DB::Rollback` exception.

Transaction lock connection for current fiber avoiding grepping new one from pool.

### Lock

#### Row level

Provides support for row-level locking using `SELECT … FOR UPDATE` and other lock types.

Chain `#find` to `#lock` to obtain an exclusive lock on the selected rows:

```crystal
# select * from contacts where id=1 for update
Contact.all.lock.find(1)
```

You can also use `Jennifer::Model::Base#lock!` method to lock one record by id. This may be better if you don't need to lock every row. Example:

```crystal
Contact.transaction do
  # select * from contacts where ...
  contacts = Contact.where { _age > 15 }.to_a
  contact = contacts.find { |c| c.name =~ /John/ }.not_nil!
  contact.lock!
  contact.age += 10
  contact.save!
end
```

You can start a transaction and acquire the lock in one go by calling with_lock with a block. The block is called from within a transaction, the object is already locked. Example:

```crystal
contact = Contact.first!
contact.with_lock do
  # This block is called within a transaction,
  # record is already locked.
  contact.age += 100
  contact.save!
end
```

#### Table level

To lock table use `Jennifer::Adapter#with_table_lock` method

```crystal
Jennifer::Adapter.default_adapter("table_name") do
  # some operations here
end
```

Or performing directly on model class:

```crystal
Contact.with_table_lock do
  # some operations here
end
```

> But **only** postgres adapter supports the real table `LOCK` statement - mysql one just wraps a call to the transaction. This is caused by performing queries with prepared statements and mysql doesn't allow lock table via it.

Database-specific information on row locking:
- [MySQL](http://dev.mysql.com/doc/refman/5.7/en/innodb-locking-reads.html)
- [PostgreSQL](http://www.postgresql.org/docs/current/interactive/sql-select.html#SQL-FOR-UPDATE-SHARE)


#### Optimistic locking

`Jennifer.cr` supports optimistic locking by using an `Int32` or `Int64` column acting as a `lock`. Each update to the record increments the `lock` column and the locking facilities ensure that records instantiated twice will let the last one saved raise a `StaleObjectError` if the first was also updated. Example:

```crystal
p1 = Person.find(1)
p2 = Person.find(1)

p1.first_name = "Michael"
p1.save

p2.first_name = "should fail"
p2.save # Raises an Jennifer::StaleObjectError
```

`StaleObjectError` could also be raised when objects are destroyed.

```crystal
p1 = Person.find(1)
p2 = Person.find(1)

p1.first_name = "Michael"
p1.save

p2.destroy # Raises an Jennifer::StaleObjectError
```

NOTE: *Only `#save` and `#destroy` check for stale data. `#update_columns` and `#delete` bypass all checks.*

To add optimistic locking to a model use macro method `with_optimistic_lock` in model class definition.
By default, it uses column `lock_version : Int32` as lock.
The column used as lock must be type `Int32` or `Int64` and the default value set to 0.
You can use a different column name as lock by passing the column name to the method.

```crystal
class MyModel < Jennifer::Model::Base
  with_optimistic_lock

  mapping(
    id: {type: Int64, primary: true},
    lock_version: {type: Int32, default: 0},
  )
end
```

Or use a custom column name for the locking column:

```crystal
class MyModel < Jennifer::Model::Base
  with_optimistic_lock :custom_lock

  mapping(
    id: {type: Int64, primary: true},
    custom_lock: {type: Int64, default: 0},
  )
end
```
