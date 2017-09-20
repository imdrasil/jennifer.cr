#### Pagination

For now you can only specify `limit` and `offset`:

```crystal
Contact.all.limit(10).offset(10)
```

#### Order

You can specifies orders to sort:
```crystal
Contact.all.order(name: :asc, id: "desc")
```
