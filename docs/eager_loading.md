As was said Jennifer provide lazy query evaluation  so it will be performed only after trying to access to element from collection (any array method - it implements Enumerable). Also you can extract first entity via `first`. If you are sure that at least one entity in db satisfies you query you can call `#first!`.

To extract only some fields rather then entire objects use `pluck`:

```crystal
Contact.all.pluck(:id, "name")
```

It returns array of values if only one field was given and array of arrays if more. It accepts raw sql arguments so be care when using this with joining tables with same field names. But this allows to retrieve some custom data from specified select clause.

```crystal
Contact.all.select("COUNT(id) as count, contacts.name").group("name")
       .having { sql("COUNT(id)") > 1 }.pluck(:count)
```

To load relations using same query joins needed tables (yep you should specify join on condition by yourself again) and specifies all needed relations in `with` (relation name not table).

```crystal
Contact.all.left_join(Address) { _contacts__id == _contact_id }.with(:addresses)
```
