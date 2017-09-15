#### Transaction

Transaction mechanism provides block-like syntax:

```crystal
Jennifer::Adapter.adapter.transaction do |tx|
  Contact.create({:name => "Chose", :age => 20})
end
```

If any error was raised in block transaction will be rollbacked. To rollback transaction raise `DB::Rollback` exception.

Transaction lock connection for current fiber avoiding grepping new one from pool.

#### Lock

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

Database-specific information on row locking:
- [MySQL](http://dev.mysql.com/doc/refman/5.7/en/innodb-locking-reads.html)
- [PostgreSQL](http://www.postgresql.org/docs/current/interactive/sql-select.html#SQL-FOR-UPDATE-SHARE)
