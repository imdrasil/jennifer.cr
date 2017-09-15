Also you can specify prepared query statement.

```crystal
scope :query_name { where { c("some_field") > 10 } }
scope :query_with_arguments { |a, b| where { (c("f1") == a) && (c("f2").in(b) } }
```

As you can see arguments are next:

- scope (query) name
- block to be executed in query contex (any query part could be passed: join, where, having, etc.)

Also they are chainable, so you could do:

```crystal
ModelName.all.where { _some_field > 1 }
         .query_with_arguments("done", [1,2])
         .order(f1: :asc).no_argument_query
```
