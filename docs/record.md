# Record

There are 2 types of query classes:
- `Jennifer::QueryBuilder::Query` - general class which allows to generate request to any table
- `Jennifer::QueryBuilder::ModelQuery(T)` - specific query for model `T`.

First one gets db result set and converts it to the hash which is wrapped by `Jennifer::Record` structure. This structure allows get field using a method call:

```crystal
# Jennifer::QueryBuilder::Query is aliased as Jennifer::Query
record = Jennifer::Query["contacts"].where { _name.like("Jho%") }.to_a[0]

record["name"]                    # Jennifer::DBAny
record.attribute("name")          # Jennifer::DBAny
record.attribute("name", String)  # String or raises Jennifer::BaseException
record.name                       # Jennifer::DBAny
record.name(String)               # Jennifer::DBAny
```

`#{{attribute_name}}` methods are generated using macros.

In major amount of cases you will use second one which will return `Array(T)`. But also with custom selects or unions `Jennifer::Record` could be retrieved using `#results`:

```crystal
Contact.all.select { [_name, _id] }.results # Array(Jennifer::Record)
```
