# Query DSL

My favorite part. Jennifer allows you to build lazy evaluated queries with chaining syntax. But some of them could be only at the and of a chain (such as `#fisrt` or `#pluck`).

#### Where

`#all` retrieves everything (only at the beginning; creates empty request)
```crystal
Contact.all
```

Specifying where clause is really flexible. Method accepts block which represents where clause of request (or it's part - you can chain several `#where` and they will be concatenated using `AND`).

To specify field use `#c` method which accepts string as field name. As I've mentioned after declaring model attributes, you can use their names inside of block: `_field_name` if it is for current table and `ModelName._field_name` if for another model. Also there you can specify attribute of some model or table using underscores: `_some_model_or_table_name__field_name` - model/table name is separated from field name by "__". You can specify relation in space of which you want to declare condition using double _ at the beginning and block. Several examples:
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
| `not_like` | `NOT LIKE` |
| `is` | `IS` and provided value |
| `not` | `NOT` and provided value (or as unary operator if no one is given) |
| `in` | `IN` |
| `between` | `BETWEEN` |

And postgres specific:

| Method | SQL variant |
| --- | --- |
| `contain` | `@>` |
| `contained` |`<@` |
| `overlap` | `&&` |

Also Jennifer supports json field path methods for criterias: `Criteria#take` (also accessible as `Criteria#[]`) and `Criteria#path`.

**MySQL**

For mysql both `take` and `path` methods behave in the same way.

Thera are 2 supported cases:

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

**PostgreSQL

- `#path` method use `#>` operator
- `#take` method use `->` operator


To specify exact sql query use `#sql` method:

```crystal
# it behaves like regular criteria
Contact.all.where { sql("age > ?",  [15]) & (_name == "Stephan") } 
```

Query will be inserted "as is". Usage of `#sql` allows to use nested plain request. Such plain sql will be surrounded by brackets (in common case).

**Tips**

- all regexp methods accepts string representation of regexp
- use parenthesis for binary operators (`&` and `|`)
- `nil` given to `!=` and `==` will be transformed to `IS NOT NULL` and `IS NULL`
- `is` and `not` operator accepts next values: `:nil`, `nil`, `:unknown`, `true`, `false`

At the end - several examples:

```crystal
Contact.where { (_id > 40) & _name.regexp("^[a-d]") }

Address.where { _contact_id.is(nil) }
```

`ANY` and `ALL` statement allow to path nested query:

```crystal
Cotnact.all.where { _id == any(Address.all.where { _main }.select(:contact_id)) }
```

##### Complex logical condition

To design some complex logcal expression like: `a & (b | c) & d` use `ExpressionBuilder#g` method:

```crystal
Contact.all.where { (_id > 0) & g(_name.like("%asd%") | _age > 15) & id < 100 }
```

##### Smart arguments parsing

Next methods provide flexible api for passing arguments:

- `#order`
- `#reorder`
- `#group`
- `#select`

Theys allows pass argument (tuple, named tuple or hash - depending on context) of `String`, `Symbol` or `Cryteria`. `String` arguments will be parsed as plain sql (`RawSql`) and `Symbol` - as `Criteria`.

#### Select

Raw sql for `SELECT` clause could be passed into `#select` method. This have highest priority during forming this query part.

```crystal
Contact.all.select("COUNT(id) as count, contacts.name").group("name")
       .having { sql("COUNT(id)") > 1 }.pluck(:name)
```

Also `#select` accepts block where all fields could be specified and aliased:

```crystal
Contact.all.select { [sql("COUNT(id)").alias("count"), _name] }.group("name")
	   .having { sql("count") > 1 }.pluck(:name)
```

#### From

Also you can provide subquery to specify FROM clause (but be carefull with source fields during result retriving and mapping to objects)

```crystal
Contact.all.from("select * from contacts where id > 2")
Contacts.all.from(Contact.where { _id > 2 })
```

#### Joins

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

#### Relation

To join model relation (has_many, belongs_to and has_one) pass it's name and join type:

```crystal
Contact.all.relation("addresses").relation(:passport, type: :left)
```

#### Relation eager loading

##### Actual eager load

To automatically join some relation and get it from db use `#eager_load` and pass relation name:

```crystal
Contact.all.eager_load("addresses")
```

If there are several eager_load with same table - Jennifer will auto alias tables.

##### Includes (preload)

To load all related objects after main query being executed use `#includes` method (or it's alias `#preload`):

```crystal
Contact.all.includes(:addresses)
```

#### Group

```crystal
Contact.all.group("name", "id").pluck(:name, :id)
```

`#group` allows to add columns for `GROUP BY` section. If passing arguments are tuple of strings or just one string - all columns will be parsed as current table columns. If there is a need to group on joined table or using fields from several tables use next:

```crystal
Contact.all.relation("addresses").group(addresses: ["street"], contacts: ["name"])
       .pluck("addresses.street", "contacts.name")
```

 Here keys should be *table names*.

#### Having

```crystal
Contact.all.group("name").having { _age > 15 }
```

`#having` allows to add `HAVING` part of query. It accepts block same way as `#where` does.

#### Exists

```crystal
Contact.where { _age > 42 }.exists? # returns true or false
```

`#exists?` check is there is any record with provided conditions. Can be only at the end of query chain - it hit the db.

#### Distinct

Adds `DISTINCT` keyword of at the very beginning of `SELECT` statement

```crystal
Contant.all.distinct # Array(Contact) with unique attributes (all)
```

#### Union

To make common SQL `UNION` you can use `#union` method which accepts nother query object. But be carefull - all selected fields should be same.

```crystal
Address.all.where { _street.like("%St. Paul%") }.union(Profile.all.where { _login.in(["login1", "login2"]) }.select(:contact_id)).select(:contact_id).results
```

In this example you can't use regular `#to_a` because result reords will be not an address or profile so it couldn't be mapped to any of these models. That's why only `Jennifer::Record` could be got.


#### None

If at some point you desides to make query to return empty result set - use next:

```crystal
q = Contats.where { _age > 19 }
q.none
q.where { _name.like("Jo%") }
q.to_a
```

But be carefull - all further chainable method calls will continue modify the object - only db call will be avoided.
