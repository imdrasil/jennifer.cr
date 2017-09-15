My favorite part. Jennifer allows you to build lazy evaluated queries with chaining syntax. But some of them could be only at the and of a chain (such as `#fisrt` or `#pluck`). Here is a list of all dsl methods:

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

And postgres specific:

| Method | SQL variant |
| --- | --- |
| `contain` | `@>` |
| `contained` |`<@` |
| `overlap` | `&&` |

To specify exact sql query use `#sql` method:

```crystal
# it behaves like regular criteria
Contact.all.where { sql("age > ?",  [15]) & (_name == "Stephan") } 
```

Query will be inserted "as is". Usage of `#sql` allows to use nested plain request.

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

#### Select

Raw sql for `SELECT` clause could be passed into `#select` method. This have highest priority during forming this query part.

```crystal
Contact.all.select("COUNT(id) as count, contacts.name").group("name")
       .having { sql("COUNT(id)") > 1 }.pluck(:name)
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

> For now Jennifer provide manual aliasing as second argument for `#join` and automatic when using `#includes` and `#with` methods. For details check out the code. 

#### Relation

To join model relation (has_many, belongs_to and has_one) pass it's name and join type:

```crystal
Contact.all.relation("addresses").relation(:passport, type: :left)
```

#### Includes

To automatically join some relation and get it from db use `#includes` and pass relation name:

```crystal
Contact.all.includes("addresses")
```

If there are several includes with same table - Jennifer will auto alias tables.

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

```crystal
Contant.all.distinct("age") # returns array of ages (Array(DB::Any | Int16 | Int8))
```

`#distinct` retrieves from db column values without repeats. Can accept column name and as optional second parameter - table name. Can be only as at he end of call chain - hit the db.
