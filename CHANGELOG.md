# 0.4.1 (20-10-2017)

**Config**

* added `port` configuration

* `::reset_config` resets to default configurations

* added validation for adapter and db

* `::from_uri` allows to load onfiguration from uri

**Adapter**

* added `#query_array` method to request array of arrays of given type

* added `#with_table_lock` which allows to lock table (mysql and postgres have different behaviors)

**Query**

* added `all` and `any` statements

* refactored logical operators - now they don't group themselves with "()"

* added `ExpressionBuilder#g` (`ExpressionBuilder#grouping`) to group some condition

* added `XOR`

* moved all executable methods to `Executables` module

* change behavior of `#distinct` - now it accepts no arguments and just prepend `DISTINCT` to common select query

* added `#find_in_batches` - allows to search over requested collection reqtrieved only determined amount of records per iteration

* `#find_records_by_sql` - returns array of `Record` by given sql string

* added `:full_outer` join type

* added `#lateral_join` to make `LATERAL JOIN` (for now is supported only by PostgreSQL)

* extracted all join methods to `Joining` module

* extracted all ordering methods to `Ordering` module

* added `#reorder` method allowing to reorder existing query

**ModelQuery**

* added `#find_by_sql` similar to `Query#find_records_by_sql`

**Model**

* added `::with_table_lock`

* added `::adapter`

* added `::import` to perform one query import

* fixed bug with reloading empty relations

**Mapping**

* added `inverse_of` option to `has_many` and `has_one` relations to sets owner during relation loading



# 0.4.0 (30-09-2017)

**Exception**

* `BadQuery` now allows to append query body to the main error text

**Adapter**

* added `#view_exists?(name)`

**QueryBuilder**

* now `#eager_load` behaves as old variant of `#includes` - via joining relations and adding them to the `SELECT` statement (**breaking changes**)

* added `#preload` method which allows to load all listed relations after execution of main request

* new behavior of `#includes` is same as `#preload` (**breaking changes**)

* added `Jennifer::QueryBuilder::QueryObject` which designed to be as a abstract class for query objects for `Model::Base` scopes (**will be renamed in futher releases**)

* all query related objects are clonable

* now `GROUP` clause is placed right after the `WHERE` clause

* aggregation methods is moved to `Jennifer::QueryBuilder::Aggregations` module which is included in the `Query` class

* `Query#select` now accepts `Criteria` object, `Symbol` (which now will be transformed to corresponding `Criteria`), 'String' (which will be transformed to `RawSql`), string and symbol tuples, array of criterias and could raise a block with `ExpressionBuilder` as a current context (`Array(Criteria)` is expeted to be returned)

* `Query#group` got same behavior as `Query#select 

* `Query#order` realize same idea as with `Query#select` but with hashes

* added `Criteria#alias` method wich allows to alias field in the `SELECT` clause

* `ExpressionBuilder#star` creates "all" attribute; allows optional argument specifing table name 

* `RawSql` now has `@use_brakets` atttribute representing if sql statement should be surrounded by brackets

* `Criteria#sql` method now accepts `use_brackets` argument which is passed to `RawSql`

**Migration**

* mysql got `#varchar` method for column definition

* added invoking of `TableBuilder::CreateMaterializedView` in `#create_materialized_view` method

* now `Jennifer::TableBuilder::CreateMaterializedView` accepts only `String` query

* added `#drop_materialized_view`

* added `CreateIndex`, `DropIndex`, `CreateView`, `DropView` classes and corresponding methods

**Record**

* added `attribute(name : String, type : T.class)` method

**Model**

* added `::context` method which return expression builder for current model

* added `::star` method which returns "all" criteria

* moved scope definition to `Scoping` module

* now scopes accepts `QueryBuilder::QueryObject` class name as a 2nd argument

* now object inserting into db use old variant with inserting and grepping last inserted id (because of bug with pg crystal driver)

**View**

* added view support for both mysql and postgres - name of abstract class for inheritance `Jennifer::View::Base`