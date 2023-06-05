# Changelog

## 0.13.0 (05-06-2023)

**General**

* address "positional parameter of the overridden method, which has a different name and may affect named argument passing" crystal `1.5.0` warning (for full list see [MR](https://github.com/imdrasil/jennifer.cr/pull/413))
* upgrade supported mysql driver version to `0.14.0`
* upgrade supported pg driver version to `0.26.0`
* add `jsonb` type support for model and migration generators
* replace `phoffer/inflector.cr` inflector library with `luckyframework/wordsmith`

**QueryBuilder**

* `Query.count` returns `Int64` instead of `Int32`
* `Query.offset` accepts `Int32` or `Int64` as input instead of only `Int32`
* `#group`, `#select` raise an `ArgumentError` if block returns anything except array
* `#having`, `#reorder`, `#order` raises `ExpressionBuilder` as a block argument
* `#where` accepts hash with string keys as well
* added `#find_or_create_by`, `#find_or_create_by!`, `#find_or_initialize_by` to create/instantiate a record if nothing was found in the DB
* added `#find_by` and `#find_by!` as a shortcut for `.where().first` and `.where().first!`

**Model**

* change default `id` attribute type from `Int32` to `Int64`
* generate a setter method for a `Int64` attribute that calls `#to_i64` on `Int32` value
* in mapping automatically assign `null: true` if `null` property is missing and field is primary
* enhance type coercion on initializing instance from hash
* change return type of `.ids` to `Array(Int64)`
* `Model.count` returns `Int64` instead of `Int32`
* add support for `JSON::PullParser` attribute class
* model class responds to: `#here`, `#select`, `#from`, `#union`, `#distinct`, `#order`, `#group`, `#with`, `#merge`, `#limit`, `#offset`, `#lock`, `#reorder`, `#count`, `#max`, `#min`, `#sum`, `#avg`, `#group_count`, `#group_max`, `#group_min`, `#group_sum`, `#group_avg`, `#with_relation`, `#includes`, `#preload`, `#eager_load`, `#last`, `#last!`, `#first`, `#first!`, `#find_by`, `#find_by!`, `#pluck`, `#exists?`, `#increment`, `#decrement`, `#ids`, `#find_records_by_sql`, `#find_in_batches`, `#find_each`, `#join`, `#right_join`, `#left_join`, `#lateral_join`
* adds `.create` and `.create!` that accepts block
* fix a bug when password digest wasn't generated when password was set by passing it to a constructor
* add missing STI initialization to constructors accepting a hash or named tuple
* use `Adapter::Base.coerce_database_value` in constructors accepting a hash or named tuple to coerce values for columns that don't have specified converter
* Fix the issue of `Jennifer::Model::OptimisticLocking#reset_lock_version` decreasing lock version column when it's not changed

**Validation**

* add `jennifer.errors.messages.required` message in locale yaml file
* `Jennifer::Model::Errors#add` accepts `String | Symbol | Proc(Translation, String, String)` for `message` argument
* `validates_inclusion`, `validates_exclusion`, `validates_format`, `validates_length`, `validates_uniqueness`, `validates_presence`, `validates_absence`, `validates_numericality`, `validates_acceptance` & `validates_confirmation` validation macros accepts `message` option that allows to specify validation message

**Relation**

* `belongs_to` relation macro accepts `required` option to validate existence of relation on save

**View**

* model class responds to: `#here`, `#select`, `#from`, `#union`, `#distinct`, `#order`, `#group`, `#with`, `#merge`, `#limit`, `#offset`, `#lock`, `#reorder`, `#count`, `#max`, `#min`, `#sum`, `#avg`, `#group_count`, `#group_max`, `#group_min`, `#group_sum`, `#group_avg`, `#with_relation`, `#includes`, `#preload`, `#eager_load`, `#last`, `#last!`, `#first`, `#first!`, `#find_by`, `#find_by!`, `#pluck`, `#exists?`, `#increment`, `#decrement`, `#ids`, `#find_records_by_sql`, `#find_in_batches`, `#find_each`, `#join`, `#right_join`, `#left_join`, `#lateral_join`

**Adapter**

* remove `id` column from the `versions` table schema
* change default `id` column type from `int` to `bigint`
* add `Base.coerce_database_value` method to provide interface to perform coercing from default database type used to read column to hash to a desired model attribute type

**SqlGenerator**

* fix invalid SQL generating for `FROM` clause when string value is given for `#from`

**Record**

* now calling a `#foo_bar` method on a record that is missing raises `ArgumentError` instead of `KeyError`

## 0.12.0 (15-12-2021)

**General**

* add crystal 1.2.0 support

**QueryBuilder**

* `#pluck` accepts splatted named tuple of desired attribute-type pairs and returns array of such tuples as a records
* `#upsert` passes expression builder as a block argument

**Model**

* add Optimistic locking support via macro `with_optimistic_lock(column_name = lock_version)`
* `updated_at` and `created_at` fields aren't override on save if have been set manually
* add `upsert` class method to insert multiple models while ignoring conflicts on specified unique fields

**Adapter**

* fix database connection query arguments building
* each adapter includes `RequestMethods` instead of including it by base adapter class
* add a new `upsert` overload that allows passing a collection of `Jennifer::Model::Base`
* fix `insert_on_duplicates` sql generation for postgres adapter if no unique fields given

**SqlGenerator**

* any `INSERT`, `UPDATE`, `SELECT` and `DELETE` requests uses quoted tables/columns if they are created by `QueryBuilder::ExpressionBuilder` (raw SQL is placed as-is)
* `.select_clause`  uses specified query attributes to select and fall back to custom fields only if there is no custom attribute to select

**Migration**

* `TableBuilder::ChangeTable` now performs `DropForeignKey`, `DropIndex` & `DropReference` before any column manipulation
* fix `TableBuilder::ChangeEnum` to use specified adapter to query effected tables

## 0.11.1 (24-08-2021)

**General**

* switch to the `crimson-knight/i18n.cr` `~> 0.4.1`

**Migration**

* fix `TableBuilder::ChangeTable#drop_reference` dropping column before reference
* add `TableBuilder::DropReference`

## 0.11.0 (20-07-2021)

**General**

* add crystal `>= 1.0.0` support
* fix inconsistent method signatures in multiple places
* add `#to_json` to the following structs: `PG::Numeric`, `PG::Geo::Point`, `PG::Geo::Line`, `PG::Geo::Circle`, `PG::Geo::LineSegment`, `PG::Geo::Box`, `PG::Geo::Path`, `PG::Geo::Polygon`, `Char`, `Time::Span`, `Slice`, `UUID`
* add `crystal-mysql: 0.13.0` support
* add `crystal-pg: 0.23.2` support

**QueryBuilder**

* add custom `#to_json` to serialize retrieved collection
* add `#where` accepting `Hash(Symbol, _)`
* add `Criteria#equal` and `Criteria#not_equal` as original implementation of `Criteria#==` and `Criteria#!=`
* add `ExpressionBuilder` `#and`, `#or` and `#xor` methods that accepts array of conditions

**Model**

* `Authentication#password` returns given unecrypted value
* add `Coercer` module with static methods to localize all coercing logic for different types
* add `.coercer` method to return object responding to all coercing methods described in `Coercer`
* `mapping` generates `.coerce_{{attribute}(value : String)` methods for every field to coerce string value to `attribute`'s type
* `mapping` generates for every non-string attribute with a setter additional `#{{attribute}}=(value : String)` setter
* allow all build methods (`.new`, `.create` and `.update`) to receive `Hash(String, String)` and coerce values to expected types
* add `.column_name` to return all field names
* fix `.field_names` from returning child's properties for parent class
* add custom `#to_json`
* change converter interface to `.from_db(DB::ResultSet, NamedTuple)`, `.from_db(DB::ResultSet, NamedTuple)` and `.from_hash(Hash, String | Symbol, NamedTuple)`
* change all existing converters to support new required interface
* add `BigDecimalConverter(T)` converter
* add `Coercer.coerce(String, (BigDecimal?).class)`
* add `time_zone_aware` option for `TimeZoneConverter` to specify whether field should respect time zone converting logic
* add support of date only and time only string formats for `TimeZoneConverter`
* add `time_format`, `date_time_format` and `date_format` to customize time, date time and date formats respectively
* fix a bug where updated_at is not set in the generated sql query from model.save
* `NumericToFloat64Converter`, `BigDecimalConverter`, `TimeZoneConverter` `#from_hash` accepts string as field value
* `BigDecimalConverter#from_hash` accepts integer and float values as field value
* fix `Errors#inspect` bug using old `UInt64#to_s` signature
* introduce `Timestamp` module that now includes `with_timestamps` macro
* reworked how `updated_at` and `created_at` fields are set before save - now they are set explicitly without utilizing callbacks
* add `Resource.where` accepting `Hash(Symbol, _)`

**Validation**

* change `Validator#validate` abstract interface to `#validate(record, **opts)`
* update all built-in validators to reflect new `Validator` interface
* make `Validator.with_blank_validation` macro to accept arguments to reference record, field name, value and blank value acceptance

**Relation**

* remove abstract `#condition_clause` & `#condition_clause(a)` declarations from `IRelation`

**View**

* add custom `#to_json`

**Adapter**

* remove abstract `#update`  declaration from `Base`
* `BaseSQLGenerator#parse_query` converts `Time` arguments to UTC only if `Config.time_zone_aware_attributes` set to `true`
* `Mysql#read_column` calls `super` if column isn't a tiny int
* `ResultParser#read_column` convert time to `Config.local_time_zone` if `Config.time_zone_aware_attributes` set to `true` or just change time zone to it otherwise

**Config**

* `.reset_config` creates new instance instead of executing `#initialize` on existing object
* add `Config.time_zone_aware_attributes` to specify whether time zone converting logic should be globally disabled

**Migration**

* add `precision` and `scale` options support for `decimal` data type

**Record**

* add custom `#to_json`
* add custom `#inspect`

## 0.10.0 (11-12-2020)

**General**

* add crystal 0.35.0 support and drop 0.34.0 support

**QueryBuilder**

* allow arbitrary `Query` instances as nested queries for CTEs
* fix failed `nil` assertion when eager load relations sequence with missing intermediate relation records
* add `IModelQuery#find(id)` to retrieve record by primary key
* add `IModelQuery#find!(id)` to retrieve record by primary key or raise `Jennifer::RecordNotFound` exception
* `ModelQuery(T)#to_a` and `ModelQuery(T)#find_by_sql` ensure `T` has loaded actual table field count before making a request

**Model**

* change model constructor hash argument type from `Hash(String, Jennifer::DBany)` to `Hash(String, AttrType)` (same for `Symbol` keys)
* `CommonMapping#attribute` uses attribute getter
* `CommonMapping#attribute` raises `Jennifer::UnknownAttribute` exception if model has no requested attribute and `raise_exception = true`
* add `CommonMapping#attribute_before_typecast` which returns given attribute in database format using attribute converter
* add `Mapping#{{attribute}}_will_change!` to mark `{{attribute}}` as changed one
* `#primary` uses getter
* any `Mapping.mapping` invocation creates `AttrType` alias to represent union of `Jennifer::DBAny` and any arbitrary type from fields definition
* change `Mapping#update_columns` argument type to `Hash(String | Symbol, AttrType)`
* `Mapping#update_columns` raises `Jennifer::UnknownAttribute` if key-value pairs include unknown attribute
* `Mapping#set_attribute` to accept `AttrType`
* `Mapping#set_attribute` raises `Jennifer::UnknownAttribute` exception if model has no requested attribute
* `Mapping#update_columns` raises `Jennifer::UnknownAttribute` if key-value pairs include unknown field
* `Mapping#arguments_to_insert` and `Mapping#arguments_to_save` use `#attribute_before_typecast` to collect attributes to store in a database
* `#add_{{relation}}` accepts `AttrType` as a hash value type
* rename `EnumConverter` to `PgEnumConverter`
* add `EnumConverter(T)` to convert string to crystal enum
* add `JSONSerializableConverter(T)` to convert JSON field to objects of `T` that support `.from_json` and `#to_json` methods
* add `TimeZoneConverter` to convert time attributes from UTC to `Jennife::Config.local_time_zone`

**Adapter**

* add `DBFormater` as a proposed default logger formatter
* change logging - emit `Log::Metadata` with  `query`, `args` and `time` keys (as new [crystal-db](https://github.com/crystal-lang/crystal-db/blob/72535518496e38f37173a98742c65fa0a569a272/src/db/statement.cr#L145) does)
* fix missing reconnect to database on connection lost

**SqlGenerator**

* fix a potential compilation issue that appears in certain edge cases for postgres adapter (#329)
`Adapter::BaseSQLGenerator` now produces valid SQL when using multiple recursive CTEs (`.with(..., true)`) in a single query

**Migration**

* rename `TableBuilder::DB_OPTIONS` to `TableBuilder::DbOptions`

**Exceptions**

* add `Jennifer::UnknownAttribute` to represent case when unknown attribute is tried to be read/written

## 0.9.0 (24-05-2020)

**General**

* add Crystal `0.34.0` support
* add `Jennifer::Presentable` with abstract methods declarations (`#attribute`, `#errors`, `#human_attribute_name`, `#attribute_metadata`, `#class_name`)

**QueryBuilder**

* `Query#initialize` now accept `Adapter::Base` as a second (optional) argument
* `OrderItem` is renamed to `OrderExpression` to avoid possible name collisions

**Model**

* fix an issue with rendering `new_record` and `destroyed` system variables by `#to_json`
* `Resource.table_prefix` now returns underscored namespace name (if any) by default
* `Base` includes `Jennifer::Presentable`
* add `Translation#class_name` method to return underscored class name
* add `Mapping#attribute_metadata` to return attribute metadata by it's name
* remove `Base::primary_field_type`
* Prevent compile time error with models named `Model` or `Record`

**View**

* fix an issue with rendering `new_record` and `destroyed` system variables by `#to_json`
* remove `Base::primary_field_type`

**Adapter**

* db connection is established on the first request no on adapter initialization
* `Adapter.adapter_class` raises `BaseException` if no valid `Config.adapter` is specified
*  `.command_interface`, `.create_database`, `.drop_database`, `.generate_schema`, `.load_schema`, `.db_connection`, `.connection_string`, `.database_exists?` now are instance methods
* `Base#initialize` now excepts `Config` instance
* respect host in `Jennifer::Postgres::CommandInterface#database_exists?`
* escape connection URI segments
* `Config#logger` now is `Log` instead of `Logger`
* add read/write adapter segregation
* deprecate `.adapter` & `.adapter_class`
* remove `.query`, `.exec` & `.scalar`

**Config**

* `.reset_config` invokes `#initialize` instead of creating new instance

**Migration**

* `Base#schema_processor` is no more public api
* `Runner.create` and `Runner.drop` now accept option `Adapter::Base` instance
* pass `to_table` in `TableBuilder::DropForeignKey#process`
* fix `TableBuilder::CreateTable#reference` - now it takes into account given SQL type for the foreign key column
* add `#add_reference`, `#drop_reference`, `#add_timestamps` to `TableBuilder::CHangeTable`
* `TableBuilder::CHangeTable#drop_index` also accepts single column name
* remove deprecated `TableBuilder::CreateTable#index` overrides

**Record**

* `#initialize(DB::ResultSet)` is removed

## 0.8.4 (15-11-2019)

**QueryBuilder**

* use adapter's `#read_column` in `NestedRelationTree`
* add `RelationTree#adapter`
* fix `Ordering#order(Hash(String | Symbol, String | Symbol))`

**Adapter**

* fix issue with treating `tinyint` mysql field as `boolean`
* remove `ResultParser#result_to_array`
* add `Mysql#read_column`
* add `Base.default_max_bind_vars_count` which returns default maximum count of bind variables that can be used in `Base#bulk_insert` (default is 32766)
* `Mysql.default_max_bind_vars_count` and `Postgres.default_max_bind_vars_count` returns `32766`
* `Base#bulk_insert` doesn't do table lock no more
* if variables that should be inserted by `Base#bulk_insert` exceed `Base.max_bind_vars` all of them are quoted and put into a query
* remove `BaseSQLGenerator::ARRAY_ESCAPE`
* move `BaseSQLGenerator::ARGUMENT_ESCAPE_STRING` to `Quoting`
* move `BaseSQLGenerator` `.quote`, `.escape_string`, `.filter_out` to `Quoting`
* add correct values quoting for `postgres` adapter
* add correct values quoting for `mysql` adapter
* now logger writes `BEGIN` instead of `TRANSACTION START`, `COMMIT` instead of `TRANSACTION COMMIT` and `ROLLBACK` instead of `TRANSACTION ROLLBACK` on corresponding transaction commands
* add `SchemaProcessor::FkEventActions` enum to validate `on_delete` and `on_update` action values; `String | Symbol` still should be used as an argument type everywhere

**Config**

* add `max_bind_vars_count` property to present maximum allowed count of bind variables to be used in bulk insert operation
* add `MigrationFailureHandler` enum to validate `migration_failure_handler_method` value; `Symbol | MigrationFailureHandler` should be used as an argument for it
* fix `migration_failure_handler_method` config - make it instance property

## 0.8.3 (19-10-2019)

**General**

* add crystal `0.31.1` compatibility
* add `crystal-db@0.7.0` support
* remove `sam` from mandatory dependencies

**Model**

* fix bug with primary field presence assertion

**View**

* fix bug with primary field presence assertion

**Adapter**

* add `date` SQL data type
* `date_time` field type maps to `timestamp` SQL data type (postgres only)

**Migration**

* add `Runner.pending_migration?` to return whether there is pending (not invoked) migration
* add `Base.with_transaction` method to disable automatic transaction wrapping around migration methods
* add `Base.with_transaction?` to check whether migration is run under a transaction
* remove `var_string` field type
* remove `blob` field type for postgres
* fix wrong explanation message for `TableBuilder::CreateIndex`
* add new `TableBuilder::CreateTable#index` signatures (old ones are deprecated):
  * `#index(fields : Array(Symbol), type : Symbol | ::Nil = nil, name : String | ::Nil = nil, lengths : Hash(Symbol, Int32) = {} of Symbol => Int32, orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)`
  * `#index(field : Symbol, type : Symbol | ::Nil = nil, name : String | ::Nil = nil, length : Int32 | ::Nil = nil, order : Symbol | ::Nil = nil)`
* make default `varchar` length `254` (mysql only)
* add foreign key ON UPDATE and ON DELETE support
* `Base#add_foreign_key` accepts `on_delete` and `on_update` keyword arguments to specify corresponding actions
* `TableBuilder::ChangeTable#add_foreign_key` accepts `on_delete` and `on_update` keyword arguments to specify corresponding actions
* `TableBuilder::CreateTable#reference` accepts `on_delete` and `on_update` options to specify corresponding actions
* `TableBuilder::CreateTable#foreign_key` accepts `on_delete` and `on_update` keyword arguments to specify corresponding actions

## 0.8.2 (11-09-2019)

**General**

* upgrade `TechMagister/i18n.cr` dependency to `0.3.1`

## 0.8.1 (04-09-2019)

**General**

* add `crystal-pg` 0.18.0 support
* add ameba check to CI
* fix bug with not defined `JSON`

**Model**

* Add `EnumConverter` converter for Postgre `ENUM` field convert
* (pg only) field presenting `ENUM` field should explicitly specify `converter: Jennifer::Model::EnumConverter`

**Adapter**

* `Postgre` adapter now doesn't register decoders for each ENUM type in `#prepare`

**Config**

* add `allow_outdated_pending_migration` configuration to specify whether outdated pending migration should be silently processed or error should be raised

**Migration**

* extend `Jennifer::Migration::TableBuilder::Base::AllowedTypes` alias with `Int64` type.

## 0.8.0 (11-06-2019)

**General**

* by default `db:migrate` task outputs information about executed migrations
* `db:create` command doesn't fail if database already exists

**QueryBuilder**

* remove redundant `Criteria#similar` which is loaded with `postgres` adapter
* add `Query#insert` and `Query#upsert`
* add `ExpressionBuilder#values` and `Values` to reference to `VALUES` statement in upsert
* `.find_by_sql` and `.to_a` of `ModelQuery(T)` use `T.new` instead of `T.build`
* add `CommonTableExpression` to present SQL CTE
* rename `EagerLoading#with` to `#with_relation`
* `#last!` and `#last` assigns old limit value back after request instead of additional `#reverse_order` call
* speed up `Query` allocation by making all query part containers nilable
* add 2nd argument to `Query#union` setting union to be `UNION ALL`
* now `Query#with` presents API for registering common table expression
* add `Query#merge`
* `Query#where` yields expression builder
* `Query`'s `#join`, `#right_join`, `#left_join` and `#lateral_join` yield expression builders of a main query and joined context
* add next SQL functions: `count`, `sum`, `avg`, `min`, `max`, `coalesce` and `concat_ws` SQL functions
* `round` function now accepts second optional argument specifying precision
* `Function`'s `#operands_to_sql` and `#operand_sql` now are public
* `Function.define` macro accepts `comment` key to specify function class documentation comment
* `Function.define` macro `arity` argument by default is `0` (instead of `-1`)
* add `ExpressionBuilder#cast`
* handle an empty array passed to `Criteria#in`
* fix missing `LIMIT` in query generated by `#first!`
* fix result type of `Executables#exists?` query method to `Bool` (thanks @skloibi)
* add `Executables#explain`

**Model**

* `Base.new` now calls `after_initialize` hooks and supports STI
* `Base.build` now is alias for `Base.new`
* properties passed to `Mapping.mapping` now is parsed before main mapping macro is executed
* `#append_{{relation_name}}` methods of `RelationDefinition` now use `.new` to build a related object
* `Resource::Supportable` alias is removed
* `Resource.search_by_sql` is removed in favour of `Resource.all.find_by_sql`
* fix bug with ignoring of field converter by a STI child
* fix default constructor for STI child - now it is generated if parent model has only `type` field without default value
* allow mapping option `column` that defines a custom column name that is mapped to this field (thank @skloibi)
* `Base#table_name` is moved to `Resource`
* `Mapping` module now can be included by another module with mapping definition
* `STIMapping` now doesn't convert result set to hash and use same logic as `Mapping`
* add `:auto` mapping option to specify whether primary key is autoincrementable

**Validation**

* change `Validations::Uniqueness` to consider field mappings when validating properties (thank @skloibi)
* allow passing multiple fields to `.validates_uniqueness` to validate combination uniqueness (thank @skloibi)

**View**

* introduce `Mapping` instead of `ExperimentalMapping`; new mapping heavily reuse `Model::Mapping`
* allow specification of property aliases via `column` option (cf. Model) (thank @skloibi)
* mapping shares same functionality as `Model`'s

**Adapter**

* remove `Base::ArgType` alias
* add `Base#upsert`
* `Postgres::Adapter#data_type_exists?` is renamed to `#enum_exists?`
* fix bug for dropping foreign key for `postgres` adapter
* remove `TableBuilderBuilders` - now `Migration::Base` creates commands by its own
* speed-up tables column count fetch at application start-up
* Fix result type of `#exists?` query method to `Bool` for `Base` and `Postgres` adapters (thanks @skloibi)
* add `Base#explain` abstract method and implementations for `Mysql` and `Postgres`

**Config**

* add `verbose_migrations` to hide or show migration details during `db:migrate` command invocation

**SqlGenerator**

* add `.insert_on_duplicate` and `.values_expression` to `BaseSQLGenerator` as abstract methods and implementations to `Postgres` and `Mysql`
* now `BaseSQLGenerator.from_clause` accepts 2 arguments (instead of 2..3) accepting table name as 2nd argument
* add `BaseSQLGenerator.with_clause` which generates CTE
* add `BaseSQLGenerator.explain`

**Migration**

* add `Base#tinyint` (not all adapter support it)
* change next `Base` instance method signature:
  * `#foreign_key_exists?(from_table, to_table = nil, column = nil, name : String? = nil)`
  * `#add_index(table_name : String | Symbol, field : Symbol, type : Symbol? = nil, name : String? = nil, length : Int32? = nil, order : Symbol? = nil)` (same for `TableBuilder::CreateTable#index` and `TableBuilder::ChangeTable#add_index`)
  * `#drop_index(table : String | Symbol, fields : Array(Symbol) = [] of Symbol, name : String? = nil)` (same for `TableBuilder::ChangeTable#drop_index`)
  * `#drop_foreign_key(to_table : String | Symbol, column = nil, name = nil)` (same for `TableBuilder::ChangeTable#drop_foreign_key`)
* add `TableBuilder::CreateTable#column` as alias to `TableBuilder::CreateTable#field`
* new signature of `TableBuilder::CreateTable#reference` - `#reference(name, type : Symbol = :integer, options : Hash(Symbol, AAllowedTypes) = DB_OPTIONS.new)`

**Record**

* for missing fields `BaseException` exception is raised instead of `KeyError`

## 0.7.1 (09-02-2019)

**QueryBuilder**

* `#pluck`, `#update`, `#db_results`, `#results`. `#each_result_set` and `#find_in_batches`of `Query` respects `#none` (returns empty result if it has being called)
* remove deprecated `QueryObject` constructor accepting array of options and `#params`

**Model**

* fix mapping issue when all `Generic`s are assumed as unions (#208)

**Validation**

* allow passing multiple fields to `.validates_uniqueness` to validate combination uniqueness

**Adapter**

* `Mysql::SchemaProcessor` now respects `false` as column default value
* `Postgres::SchemaProcessor` now respects `false` as column default value

**Config**

* introduce new configuration `pool_size` which sets `max_idle_pool_size = max_pool_size = initial_pool_size` to the given value; getter `#pool_size` returns `#max_pool_size`
* `postgres` is no more default adapter

**Migration**

* `TableBuilder::Base::AllowedTypes` alias includes `Float64` and `JSON::Any`

## 0.7.0 (08-01-2019)

**General**

* bump `sam` to `"~> 0.3.0"`
* add sam command `generate:model` to generate model and related migration
* move all logic regarding file generating to `Jennifer::Generators` space
* add `db:seed` task as a placeholder seeding task
* `db:setup` now invokes `db:seed` after `db:migrate`

**QueryBuilder**

* add `#and`, `#or` and `#xor` shortcut methods to `ExpressionBuilder`
* `Criteria#in` now accepts `SQLNode` as well
* add `Statement` module with base abstract functionality needed for query string generating
* `ExpressionBuilder#g` and `#group` now has no argument type restriction
* `Grouping#condition` now can be of `Statement` type
* `Query` includes `Statement`
* `Query#to_sql` now is `#as_sql`, `#select_args` - `#sql_args`
* `Condition` includes `Statement`
* `Executables#update` accepts block expecting `Hash(Symbol, Statement)` to be returned
* `Executables#modify` is removed in favor of new `#update` method accepting block
* now `LogicOperator` is inherited from `SQLNode`
* `#delete` and `exists?` of `Executables` do nothing when `#do_nothing?` is `true`
* add `Query#do_nothing?`
* add `Query.null` which returns `Query.new.none`
* `Join` accepts `Grouping` for `ON` condition

**Model**

* remove `Base.build_params`, `Base.parameter_converter` methods
* remove `ParameterConverter` class
* fix skipping generating default constructor by`Mapping.mapping` when at least one field has default value and all others are nilable
* `stringified_type` option is removed from the `COLUMNS_METADATA`
* `STIMapping#arguments_to_save` & `STIMapping#arguments_to_insert` now respect field converter
* `Translation` model now is includeable module
* all class methods of `Translation` are moved to `Translation::ClassMethods` which is automatically extended by target class using `included` macro
* `#lookup_ancestors` and `#human_attribute_name` methods of `Translation` are added
* `Errors#base` now is type of `Translation` instead of `Base`
* add `Base#persisted?`
* now attribute-specific rendering for `Resource#inspect` is generated by `.mapping`
* add polymorphic relation support for `has_one`, `has_many` and `belongs_to` relations
* add `:nodoc:` for almost all generated relation methods (except `#association`)
* add missing relation names for criterion in `Relation::Base` methods
* add `Relation::IPolymorphicBelongsTo`, `Relation::PolymorphicHasMany` and `Relation::PolymorphicHasOne`
* `@new_record`, `@destroyed`, `@errors`, changeset and relation attributes now is ignored by `JSON::Serializable`
* add `skip_validation` argument to `Authentication.with_authentication` macro to specify whether validation should be added
* add generating predicate method `#{{attribute}}?` for boolean attribute
* allow `Jennifer::Model::Base#attribute=` to accept not only defined type but also `Jennifer::DBAny`
* rename `Base#update_attributes` to `Base#set_attributes`

**Validation**

* all validation macros now accept `:if` key; the value may be both `Symbol` name of a method to be called or expression
* replace validation logic generated during a macro call with new validators usage: `Validations::Absence`, `Validations::Acceptance`, `Validations::Confirmation`, `Validations::Exclusion`, `Validations::Format`, `Validations::Inclusion`, `Validations::Length`, `Validations::Numericality`, `Validations::Presence`, `Validations::Uniqueness`
* remove `Jennifer::Validator` in favour of `Jennifer::Valdiations::Validator`
* all validators by default implement singleton pattern
* all validation macros are moved to `Jennifer::Validations::Macros`

**View**

* now attribute-specific rendering for `Resource#inspect` is generated by `.mapping`
* add generating predicate method `#{{attribute}}?` for boolean attribute

**Adapter**

* fix output stream for postgres schema dump
* remove legacy postgres insert
* add `Adapter#foreign_key_exists?`
* add `Mysql::SchameProcessor`
* now `Base#schema_processor` is abstract
* add `Postgres::SchemaProcessor#rename_table`
* `SchemaProcessor` now is abstract class
* all builder methods are moved from `SchemaProcessor` class to `TableBuilderBuilders` module
* fix syntax in `SchemaProcessor#drop_foreign_key`
* all `_query` arguments in `Base` methods are renamed to `query`
* `Base.extract_arguments` is removed
* `.delete`, `.exists` and `.count` of `BaseSQLGenerator` now returns string
* `Postgres.bulk_insert` is removed
* `Transaction#with_connection` ensure to release connection
* all sqlite3 related code are removed

**Config**

* fix `migration_failure_handler_method` property from being global
* add new property `model_files_path` presenting model directory (is used in a scope of model generating)
* fix ignoring `skip_dumping_schema_sql` config

**SqlGenerator**

* `.select_clause` now doesn't invoke `.from_clause` under the hood
* `.lock_clause` adds whitespaces around lock statement automatically

**Migration**

* remove `Runner.generate` and `Runner::MIGRATION_DATE_FORMAT`
* `TableBuilder::CreateTable#reference` triggers `#foreign_key` and accepts `polymorphic` bool argument presenting whether additional type column should be added; for polymorphic reference foreign key isn't added

**Exceptions**

* 'RecordNotFound' from `QueryBuilder::Query#first!` and `QueryBuilder::Query#last!` includes detailed parsed query

## 0.6.2 (23-10-2018)

**General**

* add `:nodoc:` to all internal constants and generated methods (implementing standard ORM methods) from the macros

**QueryBuilder**

* `Query` isn't extended by `Ifrit`
* add `OrderItem` to describe order direction
* add `Criteria#order`, `Criteria#asc` and `Criteria#desc` to create `OrderItem`
* add `Condition#eql?` to compare with other condition or `SQLNode` (returns `false`)
* add `Criteria#eql?`, `Grouping#eql?`, `LogicOperator#eql?`
* add `Query#order` and `Query#reorder` with accepting `OrderItem`
* now `Query#order` with block to expect a `OrderItem`
* remove `CriteriaContainer`
* `QueryObject` now is an abstract class
* changed wording for the `ArgumentError` in `#max`, `#min`, `#sum`, `#avg` methods of `Aggregation` to "Cannot be used with grouping"
* change `Query#from(_from : String | Query)` signature to `Query#from(from : String | Query)`

**Model**

* `#save` and `#update` will return `true` when is called on an object with no changed fields (all before callbacks are invoked)
* next `Base` methods become abstract: `.primary_auto_incrementable?`, `.build_params`, `#destroy`, `#arguments_to_save`, `#arguments_to_insert`
* `Base#_extract_attributes` and `Base#_sti_extract_attributes` become **private**
* all callback invocation methods become **protected**
* next `Resource` methods become abstract: `.primary`, `.field_count`, `.field_names`, `.columns_tuple`, `#to_h`, `#to_str_h`
* `Resource` isn't extended by `Ifrit`
* regenerate `.build_params` for STI models
* `Scoping.scope(Symbol,QueryObject)` now checks in runtime whether `T` of `Jennifer::QueryBuilder::ModelQuery(T)` responds to method named after the scope

**View**

* `Base#_after_initialize_callback` becomes **protected**
* `Base#_extract_attributes` becomes **private**

**Adapter**

* fix custom port not used when accessing the Postgres database

**Migration**

* `TableBuilder::Base` isn't extended by `Ifrit`
* rename `TableBuilder::ChangeTable#new_table_rename` getter to `#new_table_name`
* fix misuse of local variable in `TableBuilder::ChangeTable#rename_table`
* `TableBuilder::ChangeTable#change_column` has next changes:
  * `old_name` argument renamed to `name`
  * `new_name` argument is replaced with option in `options` arguemnt hash
  * raise `ArgumentError` if both `type` and `options[:sql_type]` are `nil`
* `TableBuilder::ChangeTable#change_column` raises `ArgumentError` if both `type` and `options[:sql_type]` are `nil`
* `TableBuilder::CreateTable#field` `data_type` argument renamed to `type`
* `TableBuilder::CreateTable#timestamps` creates fields with `null: false` by default
* `TableBuilder::CreateTable#add_index` is removed in favour of `#index`
* `.pending_versions`, `.assert_outdated_pending_migrations` and `.default_adapter` methods of `Runner`become private
* `Runner.config` is removed

## 0.6.1 (07-09-2018)

**General**

* adds `Time::Span` to supported types

**QueryBuilder**

* allows listing any `SQLNode` instance in SELECT clause (like raw SQL or functions)
* removes redundant `SQLNode#sql_args_count`
* adds `SQLNode#filterable?` function which presents if node has filterable SQL parameter
* refactors `Condition#sql_arg`
* adds `Function` base abstract class for defining custom SQL functions
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
* allows to pass SQL arguments to left hand condition statement
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

* add `AbstractMethod` exception which presents expectation of overriding current method by parents (is useful when method can't be real abstract one)
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
* `#find_records_by_sql` - returns array of `Record` by given SQL string
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
* `RawSql` now has `@use_brakets` attribute presenting whether SQL statement should be surrounded by brackets
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
