# Eager Loading

As was said Jennifer provide lazy query evaluation  so it will be performed only after invoking executing method. Here is a list of all executing methods:

- `#last` - returns last found record or `nil` if nothing was found;
- `#last!` - returns last record or raise `RecordNotFound` if nothing was foound;
- `#first` - returns first found record or `nil` if nothing was found;
- `#first!` - returns first record or raise `RecordNotFound` if nothing was foound;
- `#pluck` - returns array of specified fields values instead of records;
- `#delete` - deletes all records in db by query;
- `#exists?` - checks if there is any record in DB that fits query;
- `#update` - updates fields by given values;
- `#modify` - modify fields by given values using specified operators;
- `#increment` - increments fields by given values;
- `#decrement` - decrements fields by given values;
- `#to_a` - calls `#results`;
- `#db_results` - returns array of hashes found by query execution;
- `#results` - returns array of results found by query execution;
- `#ids` - plucks `id` field and converts it to the `Int32`;
- `#each` - calls `#to_a` and yields each object;
- `#each_result_set` - perform request and yield each result set;
- `#find_in_batches` - retrieves from db result sets of given size and yields them;
- `#find_each` - same as `#find_in_batches` but yields each result instead of array;
- `#find_records_by_sql` - returns array of `Jennifer::Record` found by given plain sql request;
- `#destroy` - invokes `#to_a` and calls `#destroy` on each record`.

Also you can extract first entity via `first`. If you are sure that at least one entity in db satisfies you query you can call `#first!`.

To extract only some fields rather then entire objects use `#pluck`:

```crystal
Contact.all.pluck(:id, "name")
```

It returns array of values if only one field was given and array of arrays if more. By default if uses scope of current table (e.g. in previous example select clause included `contacts.id`). To allow grepping custom fields or any statement you need to specify custom select clause:

```crystal
Contact.all.select("COUNT(id) as count, contacts.name").group("name")
       .having { sql("COUNT(id)") > 1 }.pluck(:count)
```

### Relation Eager Loading

To load relations using same query joins needed tables (yep you should specify join on condition by yourself again) and specifies all needed relations in `with` (relation name not table).

```crystal
Contact.all.left_join(Address) { _contacts__id == _contact_id }.with(:addresses)

# or simpler

Contact.all.relation(:addresses).with(:addresses)
```

But there is also similar functionality as for Rails Eager Loading - methods `#includes`, `#eager_load` and `#preload`. For now `#includes` (and `#preload`) uses preloading strategy - all specified relations will be loaded in separated requests and will be setted to appropriate owner. E.g.:

```crystal
Contact.all.includes(:addresses)
# or
Contact.all.preload(:addresses)
```

`#eager_load` joins all relations to the request using `LEFT OUTER JOIN`:

```crystal
Contact.all.eager_load(:addresses)
```

> Note: in such way only relations of given model could be loaded, e.g. not relation of relation `:addresses` could be retrieved in the upper example.