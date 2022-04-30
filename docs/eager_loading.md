# Eager Loading

As was said Jennifer provide lazy query evaluation so it will be performed only after invoking executing method. Here is a list of all executing methods:

- `#last` - returns last found record or `nil` if nothing was found;
- `#last!` - returns last record or raise `RecordNotFound` if nothing was found;
- `#first` - returns first found record or `nil` if nothing was found;
- `#first!` - returns first record or raise `RecordNotFound` if nothing was found;
- `#pluck` - returns array of specified fields values instead of records; also can return array of named tuples;
- `#delete` - deletes all records in db by query;
- `#exists?` - checks if there is any record in DB that fits query;
- `#update` - updates fields by given values;
- `#modify` - modify fields by given values using specified operators;
- `#increment` - increments fields by given values;
- `#decrement` - decrements fields by given values;
- `#to_a` - calls `#results`;
- `#db_results` - returns array of hashes found by query execution;
- `#results` - returns array of results found by query execution;
- `#ids` - plucks `id` field as `Int64` array;
- `#each` - calls `#to_a` and yields each object;
- `#each_result_set` - perform request and yield each result set;
- `#find_in_batches` - retrieves from db result sets of given size and yields them;
- `#find_each` - same as `#find_in_batches` but yields each result instead of array;
- `#find_records_by_sql` - returns array of `Jennifer::Record` found by given plain SQL request;
- `#destroy` - invokes `#to_a` and calls `#destroy` on each record`.

#### Pluck

User `#pluck` as a shortcut to select one or more attributes without loading a bunch of records to grab the attributes you want.

```crystal
Contact.all.pluck(:name)
```

instead of

```crystal
Contact.all.map(&.name)
```

`#pluck` returns array of values if only one field was given and array of arrays otherwise. If query object has no specified custom attributes to select given attributes is used to compose `SELECT` clause (query's table is used as a target - `contacts.name` for example above).

To grab custom attributes you need to specify custom select clause:

```crystal
Contact.all
  .select("COUNT(id) as count") # same as .select { [sql("COUNT(id)").alias("count")] }
  .group("name")
  .having { sql("COUNT(id)") > 1 }
  .pluck(:count)
```

To return array of named tuple instead of array of arrays specify fields and desired data types as splatted named tuple:

```crystal
Contact.all
  .select { [sql("COUNT(id)").alias("count"), _name] }
  .group("name")
  .having { sql("COUNT(id)") > 1 }
  .pluck(count: Int32, name: String) # => Array(NamedTuple(count: Int32, name: String))
```

## Relation Eager Loading

To prevent N+1 problem you may want to automatically load some related objects. There 3 possible ways how to do this:

- using `#eager_load` - will automatically join all provided relations using `LEFT OUTER JOIN`;
- using `#relation` (or manual joining) + `#with` - works as `#eager_load` but allows you to manipulate loaded records;
- using `#includes`/`#preload` - will load all specified relations using separate requests.

Examples:

```crystal
# #eager_load
Contact.all.eager_load(:addresses)

# manual eager load
Contact.all.left_join(Address) { _contacts__id == _contact_id }.with_relation(:addresses)

# #includes/#preload
Contact.all.includes(:addresses)
# or
Contact.all.preload(:addresses)
```

> NOTE: `#preload` is just an alias for `#includes`.

Also `#eager_load` and `#includes` accepts splatted named tuple as last arguments specifying nested relations to load:

```crystal
City.all.eager_load(country: { contact: [:passport, :addresses]})
```
