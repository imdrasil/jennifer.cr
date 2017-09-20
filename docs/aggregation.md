There are 2 types of aggregation functions: ones which are orking without GROUP clause and returns single values (e.g. `max`, `min`, `count`) and ones, working with GROUP clause and returning array of values.

#### Max

```crystal
Contact.all.max(:name, String)
```

#### Min

```crystal
Contact.all.min(:age, Int32)
```

#### Avg

```crystal
Contact.all.avg(:age, Float64) # mysql specific
Contact.all.avg(:age, PG::Numeric) # Postgres specific
```

#### Sum

```crystal
Contact.all.sum(:age, Float64) # mysql specific
Contact.all.sum(:age, Int64) # postgres specific
```

#### Count

```crystal
Contact.all.count
```

#### Group Max

```crystal
Contact.all.group(:gender).group_max(:age, Int32)
```

#### Group Min

```crystal
Contact.all.group(:gender).group_min(:age, Int32)
```

#### Group Avg

```crystal
Contact.all.group(:gender).group_avg(:age, Float64) # mysql specific
Contact.all.group(:gender).group_avg(:age, PG::Numeric) # Postgres specific
```

#### Group Sum

```crystal
Contact.all.group(:gender).group_sum(:age, Float64) # mysql specific
Contact.all.group(:gender).group_sum(:age, Int64) # postgres specific
``` 

#### Group Count

```crystal
Contact.all.group(:gender).group_count(:age)
```
