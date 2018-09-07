# Changelog

## Future release (__-__-2018)

## 0.6.1 (07-09-2018)

**General**

* adds `Time::Span` to supported types

**QueryBuilder**

* allows listing any `SQLNode` instance in SELECT clause (like raw sql or functions)
* removes redundant `SQLNode#sql_args_count`
* adds `SQLNode#filterable?` function which presents if node has filterable sql parameter
* refactors `Condition#sql_arg`
* adds `Function` base abstract class for defining custom sql functions
* adds `lower`, `upper`, `current_timestamp`, `current_date`, `current_time`, `now`, `concat`, `abs`, `ceil`, `floor`, `round`
* adds `Join#filterable?` and `Query#filterable?`
* raise `AmbiguousSQL` when `%` symbol is found in the raw SQL (except `%s`)

**Model**

* replaces mapping option `numeric_converter` with new `converter`
* adds `NumericToFloat64Converter` and `JSONConverter`
* now `#to_h` and `#to_str_h` use field getter methods
* remove `puts` from `JSONConverter#from_db`

**Adapter**

* propagate native `DB::Error` instead of wrapping it into `BadQuery`
* manually release a connection when an exception occurs under the transaction

**Config**

* set default `max_pool_size` to 1 and warn about danger of setting different `max_pool_size`, `max_idle_pool_size` and `initial_pool_size`

**Migration**

* adds `Migration::TableBuilder::CreateForeignKey` & `Migration::TableBuilder::DropForeignKey`
* adds `Migration::Base#add_foreign_key` & `Migration::Base#drop_foreign_key`
* adds `Migration::TableBuilder::ChangeTable#add_foreign_key` & `Migration::TableBuilder::ChangeTable#drop_foreign_key`

**Exceptions**

* add `AmbiguousSQL` - is raised when forbidden `%` symbol is used in the raw SQL

## 0.6.0 (06-07-2018)

**General**

* adds support of crystal `0.25.0`
* removes `time_zone` dependency
* removes requiring `"inflector/string"`
* adds cloning to `Time::Location` & `Time::Location::Zone`
* removes `Ifrit.typed_hash` and `Ifrit.typed_array` usage
* presents "mapping types" which allows reusing common type definition
* now `Primary32` and `Primary64` are mapping types (not aliases of `Int32` and `Int64`)
* removes `accord` dependency

**QueryBuilder**

* allows nested eager loading in `ModelQuery(T)#eager_load` and `ModelQuery(T)#include`
* all query eager loading methods are extracted to separate module `QueryBuilder::EagerLoading` which is included in `QueryBuilder::IModelQuery`

**Model**

* introduces model virtual attributes
* adds `Mapping.build_params` and `ParameterConverter` class for converting `Hash(String, String)` parameters to acceptable by model
* allows to specify table prefix
* all relations are stored in `Base::RELATIONS`
* fixes building of sti objects using parent class
* adds `Jennifer::Model::Authentication` module with authentication logic
* fixes compile time issue with `IRelation` when app has no belongs-to relation defined
* fixes bug with reading `Int64` primary key
* adds `#inspect`
* adds `numeric_converter` mapping option for numeric postgres field
* introduces new `Jennifer::Model::Errors` class replacing `Accord::ErrorList` which mimics analogic rails one a lot;
* moves `Translation::human_error` method functionality to introduced `Errors` instance level
* now next `Resource` static methods are abstract: `actual_table_field_count`, `primary_field_name`, `build`, `all`, `superclass`
* `Resource#inspect` returns simplified version (only class name and object id)
* `Resource.all` now is a macro method
* fixes `Model::Translation.lookup_ancestors` from breaking at compilation time
* now all built-in validations use attribute getter methods instead of variables

**View**

* removes `ExperimentalMapping#attributes_hash`, `ExperimentalMapping.strict_mapping?`

**Config**

* `local_time_zone` now is a `Time::Location`
* local time zone is loaded using `Time::Location.local` as default value

**SqlGenerator**

* replaces `\n` with whitespace character as query part separator

**Migration**

* now migration version is taken from file name timestamp
* `Jennifer::Migration::Base.migrations` returns a hash of version number => migration class instead of array of classes

## 0.5.1 (02-05-2018)

**QueryBuilder**

* fixes bug with compiling application without defined any model (as a result no `ModelQuery` class is defined as well)
* allows to pass sql arguments to left hand condition statement
* fixes bug with invalid order direction type interpretation (#124)

**Adapter**

* adds command interface layer for invoking console tool utilities (e.g. for dumping database schema)
* adds docker command interface

**Config**

* makes `Config` to realize singleton pattern instead of holding all data as class variables
* adds flag to skip dumping database schema after running migrations
* fixes connection port definition (#121)

## 0.5.0 (13-02-2018)

* `ifrit/core` pact is required
* adds `i18n` lib support
* adds `time_zone` lib support

**QueryBuilder**

* now `#destroy` uses `#find_each`
* adds `#patch` and `#patch!` which invokes `#update` on each object
* introduced `CriteriaContainer` to resolve issue with using `Criteria` object as a key for `@order` hash
* all `#as_sql` methods now accept `SQLGenerator` class

**Model**

* added methods `#update` & `#update!` which allows to massassign attributes and store object to the db
* added support of localization lib (i18n)
* added methods `::human_attribute_name`, `::human_error` and `::human` to translate model attribute name, error message and model name
* added own `#valid?` and `#validate!` methods - they performs validation and trigger callbacks each call
* added `#invalid?` - doesn't trigger validation and callbacks
* moved all validation error messages to yaml file
* now `%validates_with` accepts oly one class and allows to pass extra arguments to validator class
* `%validate_presence_of` is renamed to `%validate_presence`
* adds new validation macros: `%validate_absence`, `%validates_numericality`, `%validates_acceptance` and `%validates_confirmation`
* introduced own validator class
* adds `after_update`/`before_update` callbacks
* adds `after_commit`/`after_rollback` callbacks
* reorganizes the way how callback method names are stored
* now `%mapping` automatically guess is it should be sti or common mapping (should be used in places of `%sti_mapping`)
* removed `#attributes_hash`
* any time object is converted to UTC when is stored and to local when is retrieved from db

**View**

* any time object is converted to local when is retrieved from db

**Config**

* adds `::local_time_zone_name` method to set application time zone
* adds `::local_time_zone` - returns local time zone object

**Adapter**

* any time object passed as argument is converted from local time to UTC
* `postgres` adapter now use `INSERT` with `RETURNING`
* now several adapters could be required at the same time
* all schema manipulation methods now in located in the `SchemaProcessor`

## 0.4.3 (2-01-2018)

* All macro methods were rewritten to new 0.24.1 crystal syntax

**Adapter**

* removed `Jennifer::Adapter::TICKS_PER_MICROSECOND`
* fixes `Jennifer::Adapter::Mysql#table_column_count` bug

**Model**

* add `Primary32` and `Primary64` shortcuts for primary key mapping (view mapping respects this as well)
* add `::create!` & `::create` with splatted named tuple arguments
* now relation retrieveness is updated for any superclass relations as well
* a relation will be retrieved from db for only persisted record
* move `Jennifer::Mode::build` method to `%mapping` macro
* allow retrieving and building sti records using base class
* fix `#reload` method for sti record
* optimize building sti record from hash

**QueryBuilder**

* fix `Criteria#not`
* add `Criteria#ilike`

**View**

* introduce `View::Materialized` superclass for materialized views
* add `COLUMNS_METADATA` constant
* add `::columns_tuple` which returns `COLUMNS_METADATA`
* remove `::children_classes`
* make `after_initialize` callback respect inheritance
* add `::adapter`

**Exceptions**

* add `AbstractMethod` exception which represents expectation of overriding current method by parents (is useful when method can't be real abstract one)
* add `UnknownSTIType`

## 0.4.2 (24-11-2017)

**SqlGenerator**

* rename `#trancate` to `#truncate`

**Migration**

* rename `TableBuilder::DropIndex` to `TableBuilder::DropIndex`
* remove printing out redundant execution information during db drop and create
* remove `Migration::Base::TABLE_NAME` constant
* allow to pass `QueryBuilder::Query` as source to the `CreateMaterializedView` (postgres only)

**Model**

* move `Base#build` method without arguments to `Mapping` module under the `%mapping`
* added `validates_presence_of` validation macros
* fixed callback invocation from parent classes
* add `allow_blank` key to `validates_inclusion`, `validates_exclusion`, `validates_format`
* add `ValidationMessages` module which includes methods generating validation error messages
* add `Primary32` and `Primary64` shortcuts for `Int32` and `Int64` primary field declarations for model and view
* allow use nil usions instead of `null: true` named tuple option

**QueryBuilder**

* `#count` method is moved from `Executables` module to the `Aggregations` one
* changed method signature of `#find_in_batches`
* add `#find_each` - works same way as `#find_in_batches` but yields each record instead of array
* add `#ordered?` method to `Ordering` module
* switch `Criteria#hash` to use `object_id` as seed
* add `Query#eql?`
* add `Query#clone` and all related methods
* add `Query#except` - creates clone except given clauses
* make `IModelQuery` class as new superclass of `ModelQuery(T)`; move all methods no depending on `T` to the new class

## 0.4.1 (20-10-2017)

**Config**

* added `port` configuration
* `::reset_config` resets to default configurations
* added validation for adapter and db
* `::from_uri` allows to load configuration from uri

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
* added `#find_in_batches` - allows to search over requested collection required only determined amount of records per iteration
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

## 0.4.0 (30-09-2017)

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

* `Query#select` now accepts `Criteria` object, `Symbol` (which now will be transformed to corresponding `Criteria`), 'String' (which will be transformed to `RawSql`), string and symbol tuples, array of criterion and could raise a block with `ExpressionBuilder` as a current context (`Array(Criteria)` is expected to be returned)
* `Query#group` got same behavior as `Query#select`
* `Query#order` realize same idea as with `Query#select` but with hashes
* added `Criteria#alias` method which allows to alias field in the `SELECT` clause
* `ExpressionBuilder#star` creates "all" attribute; allows optional argument specifying table name
* `RawSql` now has `@use_brakets` attribute representing if sql statement should be surrounded by brackets
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