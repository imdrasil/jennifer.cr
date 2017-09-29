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