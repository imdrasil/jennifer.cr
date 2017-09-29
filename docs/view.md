### Views

#### Materialized

> Materialized view is supported only for postgre adapter

For defining materialized view `Jennfer::Model::Base` superclass should be used. And common restriction for obligatory primary field is also applied here as well.

To refresh content of materialized view use:

```crystal
Jennifer::Adapter.adapter.refresh_materialized_view("materialized_view_name")
```