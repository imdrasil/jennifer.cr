# Query DSL

My favorite part. Jennifer allows you to build lazy evaluated queries with chaining syntax. But some of them could be only at the and of a chain (such as `#first` or `#pluck`).

## Where

`#all` retrieves everything (only at the beginning; creates empty request)

```crystal
Contact.all
```

Specifying where clause is really flexible. Method accepts block which represents where clause of request (or it's part - you can chain several `#where` and they will be concatenated using `AND`).

To specify field use `#c` method which accepts string as field name. As I've mentioned after declaring model attributes, you can use their names inside of block: `_field_name` if it is for current table and `ModelName._field_name` if for another model. Also there you can specify attribute of some model or table using underscores: `_some_model_or_table_name__field_name` - model/table name is separated from field name by "__". You can specify relation in space of which you want to declare condition using double `_` at the beginning and block. Several examples:

```crystal
Contact.where { c("id") == 1 }
Contact.where { _id == 1 }
Contact.all.join(Address) { Contact._id == _contact_id }
Contact.all.relation(:addresses).where { __addresses { _id > 1 } }
Contact.all.where { _contacts__id == 1 }
```

Also you can use `primary` to mention primary field:

```crystal
Passport.where { primary.like("%123%") }
```

Supported operators:

| Operator | SQL variant |
| --- | --- |
| `==` | `=` |
| `!=` |`!=` |
| `<` |`<` |
| `<=` |`<=` |
| `>` |`>` |
| `>=` |`>=` |
| `=~` | `REGEXP`, `~` |
| `&` | `AND` |
| `|` | `OR` |
| `xor` | `XOR` |

And operator-like methods:

| Method | SQL variant |
| --- | --- |
| `regexp` | `REGEXP`, `~` (accepts `String`) |
| `not_regexp` |`NOT REGEXP` |
| `like` | `LIKE` |
| `ilike` | `ILIKE` for pg and `LIKE` for mysql |
| `not_like` | `NOT LIKE` |
| `is` | `IS` and provided value |
| `not` | `NOT` and provided value (or as unary operator if no one is given) |
| `in` | `IN` |
| `between` | `BETWEEN` |

Postgres specific:

| Method | SQL variant |
| --- | --- |
| `contain` | `@>` |
| `contained` |`<@` |
| `overlap` | `&&` |

Also Jennifer supports json field path methods for criterias: `Criteria#take` (also accessible as `Criteria#[]`) and `Criteria#path`.

### MySQL

For mysql both `take` and `path` methods behave in the same way.

There are 2 supported cases:

*
```SQL
WHERE field_name->"$.selector"
```

could be specified using

```crystal
where { _field_name["$.selector"]}
```

*
```SQL
WHERE field_name->"$[1]"
```

can be specified as:

```crystal
where { _field_name.take(1) }
```

### PostgreSQL

* `#path` method use `#>` operator
* `#take` method use `->` operator

### Tips

* all regexp methods accepts string representation of regexp;
* use parenthesis with binary operators (`&` and `|`);
* `nil` given to `!=` and `==` will be transformed to `IS NOT NULL` and `IS NULL`;
* `is` and `not` operator accepts next values: `nil`, `:unknown`, `true` and `false`;
* `ANY` and `ALL` statement allow to path nested query.

Several examples:

```crystal
Contact.where { (_id > 40) & _name.regexp("^[a-d]") }

Address.where { _contact_id.is(nil) }

nested_query = Address.all.where { _main }.select(:contact_id)
Contact.all.where { _id == any(nested_query) }
```

#### Raw query

To specify exact SQL query use `#sql` method:

```crystal
# it behaves like regular criteria
Contact.all.where { sql("age > ?",  [15]) & (_name == "Stephan") }
```

Query will be inserted "as is". Prefer to avoid such usage but it allows to use database specific functions and features. By default given SQL statement is surrounded with brackets, to avoid them - pass `false` as 2nd (or 3rd) argument.

`#sql` also excepts prepared arguments. To mark place to be replaced with db specific argument placeholder(? for mysql and $ notation for postgres) use common crystal `%s`:

```crystal
Contact.where { _name == sql("lower(%s)", ["Sam"], false) }
```

which will be transformed to:

```SQL
SELECT contacts.*
FROM contacts
WHERE contacts.name = lower($1)
```

#### Complex logical condition

To design some complex logical expression like `a & (b | c) & d` use `ExpressionBuilder#g` method:

```crystal
Contact.all.where do
  (_id > 0) & g(_name.like("%asd%") | _age > 15) & (id < 100)
end
```

#### Functions

There is special mechanism to define sql functions like `CURRENT_DATE`, `ABS` or `CONCAT`. There is already a predefined list of such functions so you can use them in the expression builder context:

```crystal
Contact.all.where { ceil(_balance) > 10 }
```

Here is the list of such functions:

* lower
* upper
* current_timestamp
* current_date
* current_time
* now
* concat
* abs
* ceil
* floor
* round

To define own function:

```crystal
Jennifer::QueryBuilder::Function.define("ceil", arity: 1) do
  def as_sql(generator)
    "CEIL(#{operand_sql(operands[0], generator)})"
  end
end
```

It is necessary to define `#as_sql` method, which returns function sql. `#operands` is an array of given function arguments. `#operand_sql` is a helper method to automatically parse how a given argument should be inserted to the sql.

#### Smart arguments parsing

Next methods provide flexible api for passing arguments:

* `#order`
* `#reorder`
* `#group`
* `#select`

They allows pass argument (tuple, named tuple or hash - depending on context) of `String`, `Symbol` or `Cryteria`. `String` arguments will be parsed as plain sql (`RawSql`) and `Symbol` - as `Criteria`.

## Select

Raw sql for `SELECT` clause could be passed into `#select` method. This have highest priority during forming this query part.

```crystal
Contact.all.select("COUNT(id) as count, contacts.name").group("name")
       .having { sql("COUNT(id)") > 1 }.pluck(:name)
```

Also `#select` accepts block where all fields could be specified and aliased:

```crystal
Contact.all
  .select { [sql("COUNT(id)").alias("count"), _name] }
  .group("name")
  .having { sql("count") > 1 }.pluck(:name)
```

## From

Also you can provide subquery to specify FROM clause (but be careful with source fields during result retrieving and mapping to objects)

```crystal
Contact.all.from("select * from contacts where id > 2")
Contacts.all.from(Contact.where { _id > 2 })
```

## Joins

To join another table you can use `join` method passing model class or table name (`String`) and join type (default is `:inner`).

```crystal
field = "contact_id"
table = "passports"
Contact.all.join(Address) { Contact._id == _contact_id }.join(table) { c(field) == _id }
```

Query, built inside of block, will passed to `ON` section of `JOIN`. Current context of block is joined table.

Also there is two shortcuts for left and right joins:

```crystal
Contact.all.left_join(Address) { _contacts__id == _contact_id }
Contact.all.right_join("addresses") { _contacts__id == c("contact_id") }
```

> For now Jennifer provide manual aliasing as second argument for `#join` and automatic when using `#eager_load` and `#with` methods. For details check out the code.

## Relation

To join model relation (has_many, belongs_to and has_one) pass it's name and join type:

```crystal
Contact.all.relation("addresses").relation(:passport, type: :left)
```

### Relation eager loading

#### Actual eager load

To automatically join some relation and get it from db use `#eager_load` and pass relation name:

```crystal
Contact.all.eager_load("addresses")
```

If there are several eager_load with same table - Jennifer will auto alias tables.

#### Includes (preload)

To load all related objects after main query being executed use `#includes` method (or it's alias `#preload`):

```crystal
Contact.all.includes(:addresses)
```

## Group

```crystal
Contact.all.group("name", "id").pluck(:name, :id)
```

`#group` allows to add columns for `GROUP BY` section. If passing arguments are tuple of strings or just one string - all columns will be parsed as current table columns. If there is a need to group on joined table or using fields from several tables use next:

```crystal
Contact.all.relation("addresses").group(addresses: ["street"], contacts: ["name"])
       .pluck("addresses.street", "contacts.name")
```

 Here keys should be *table names*.

## Having

```crystal
Contact.all.group("name").having { _age > 15 }
```

`#having` allows to add `HAVING` part of query. It accepts block same way as `#where` does.

## Exists

```crystal
Contact.where { _age > 42 }.exists? # returns true or false
```

`#exists?` check is there is any record with provided conditions. Can be only at the end of query chain - it hit the db.

## Distinct

Adds `DISTINCT` keyword of at the very beginning of `SELECT` statement

```crystal
Contact.all.distinct # Array(Contact) with unique attributes (all)
```

## Union

To make common SQL `UNION` you can use `#union` method which accepts other query object. But be careful - all selected fields should have same name and type.

```crystal
Address.all.where { _street.like("%St. Paul%") }.union(Profile.all.where { _login.in(["login1", "login2"]) }.select(:contact_id)).select(:contact_id).results
```

In this example you can't use regular `#to_a` because result records will be not an address or profile so it couldn't be mapped to any of these models. That's why only `Jennifer::Record` could be got.

## None

If at some point you decides to make query to return empty result set - use next:

```crystal
q = Contacts.where { _age > 19 }
q.none
q.where { _name.like("Jo%") }
q.to_a
```

But be careful - all further chainable method calls will continue modify the object - only db call will be avoided.
