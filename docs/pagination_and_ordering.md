# Pagination & Ordering

## Pagination

For now you can only specify `limit` and `offset`:
`#limit` only accepts an `Int32` while you can pass an `Int32` or `Int64` number to the `#offset`.

```crystal
Contact.all.limit(10).offset(10)
# Or an offset in Int64
Contact.all.limit(10).offset(10_i64)
```

## Order

You can specifies orders to sort by:

```crystal
# named tuple
Contact.all.order(name: :asc, id: "desc")
# symbol key hash
Contact.all.order({:name => :asc})
# string key hash
Contact.all.order({"name" => :asc})
# with block returning array of Jennifer::QueryBuilder::OrderExpression
Contact.all.order { [_name.asc] }
# or pass it as an argument
Contact.all.order(Contact._name.asc)
```

Any symbol-based names are considered as a column names. Any string-based - as raw SQL.

### Reorder

To avoid all existing ordering and assign new one:

```crystal
c = Contact.all.order(name: :desc)
c.reoder(id: :asc).to_a
```
