# Pagination & Ordering

#### Pagination

For now you can only specify `limit` and `offset`:

```crystal
Contact.all.limit(10).offset(10)
```

#### Order

You can specifies orders to sort:
```crystal
Contact.all.order(name: :asc, id: "desc")
Contact.all.order{ { _name => :asc, _id => "desc" } }
```

##### Reorder

To avoid all existing ordering and assign new one:

```crystal
c = Contact.all.order(name: :desc)
c.reoder(id: :asc).to_a
```