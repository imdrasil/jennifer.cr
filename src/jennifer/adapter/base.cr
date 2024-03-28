require "db"
require "./shared/*"
require "./transactions"
require "./result_parsers"
require "./request_methods"

module Jennifer
  module Adapter
    abstract class Base
      # NOTE: if any request will be performed before response of the previous one is finished
      # we will get freezed.

      enum ConnectionType
        Root
        DB
      end

      module AbstractClassMethods
        # Default database specific maximum count of bind variables
        abstract def default_max_bind_vars_count

        abstract def protocol : String
      end

      alias ArgsType = Array(DBAny)

      extend AbstractClassMethods
      include Transactions
      include ResultParsers

      @db : DB::Database?
      getter config : Config

      def initialize(@config : Config)
      end

      def db : DB::Database
        @db || begin
          @db = DB.open(connection_string(:db))
          prepare
          @db.not_nil!
        end
      end

      def prepare
        models = Hash(String, Array(Jennifer::Model::Base.class)).new do |hash, name|
          hash[name] = [] of Jennifer::Model::Base.class
        end

        ::Jennifer::Model::Base.models.each do |model|
          models[model.table_name] << model
        end

        tables_column_count(models.keys).each do |record|
          count = record.count(Int64).to_i
          models[record.table_name(String)].each do |model|
            next if model.adapter != self

            model.actual_table_field_count = count
          end
        end
      end

      def exec(query : String, args : ArgsType = [] of DBAny) : DB::ExecResult
        with_connection { |conn| log_query(query, args) { conn.exec(query, args: args) } }
      rescue e : BaseException
        BadQuery.prepend_information(e, query, args)
        raise e
      rescue e : DB::Error | TypeCastError
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, query, args)
      end

      def query(query : String, args : ArgsType = [] of DBAny, &)
        with_connection { |conn| log_query(query, args) { conn.query(query, args: args) { |rs| yield rs } } }
      rescue e : BaseException
        BadQuery.prepend_information(e, query, args)
        raise e
      rescue e : DB::Error | TypeCastError
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, query, args)
      end

      def scalar(query : String, args : ArgsType = [] of DBAny)
        with_connection { |conn| log_query(query, args) { conn.scalar(query, args: args) } }
      rescue e : BaseException
        BadQuery.prepend_information(e, query, args)
        raise e
      rescue e : DB::Error | TypeCastError
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, query, args)
      end

      def truncate(klass : Class)
        truncate(klass.table_name)
      end

      def truncate(table_name : String)
        exec sql_generator.truncate(table_name)
      end

      def delete(query : QueryBuilder::Query)
        exec(*parse_query(sql_generator.delete(query), query.sql_args))
      end

      def exists?(query : QueryBuilder::Query) : Bool
        scalar(*parse_query(sql_generator.exists(query), query.sql_args)) == 1
      end

      def count(query : QueryBuilder::Query)
        scalar(*parse_query(sql_generator.count(query), query.sql_args)).as(Int64)
      end

      def bulk_insert(collection : Array(Model::Base))
        return collection if collection.empty?

        klass = collection[0].class
        fields = collection[0].arguments_to_insert[:fields]

        if fields.size * collection.size <= max_bind_vars_count
          model_prepared_statement_bulk_insert(collection, klass, fields)
        else
          model_escaped_bulk_insert(collection, klass, fields)
        end
        collection
      end

      def bulk_insert(table : String, fields : Array(String), values : Array(ArgsType))
        return if values.empty?
        if fields.size != values[0].size
          raise ArgumentError.new("Expected #{fields.size} values per row to be passed but #{values[0].size} was")
        end

        if fields.size * values.size <= max_bind_vars_count
          flat_values = values.flatten
          exec(*parse_query(sql_generator.bulk_insert(table, fields, values.size), flat_values))
        else
          exec(sql_generator.bulk_insert(table, fields, values))
        end
      end

      def upsert(collection : Array(Model::Base), unique_fields : Array, definition : Hash = {} of Nil => Nil)
        return collection if collection.empty?

        klass = collection[0].class

        all_arguments_to_insert = collection.map(&.arguments_to_insert)
        fields = all_arguments_to_insert[0][:fields]
        values = all_arguments_to_insert.map(&.[:args])

        upsert(klass.table_name, fields, values, unique_fields, definition)
      end

      def upsert(table : String, fields : Array(String), values : Array(ArgsType), unique_fields : Array, on_conflict : Hash)
        query = sql_generator.insert_on_duplicate(table, fields, values.size, unique_fields, on_conflict)
        args = [] of DBAny
        values.each { |row| args.concat(row) }
        on_conflict.each { |_, value| add_field_assign_arguments(args, value) }

        exec(*parse_query(query, args))
      end

      def log_query(query : String, args : Enumerable, &)
        time = Time.monotonic
        res = yield
        time = Time.monotonic - time
        Config.logger.debug &.emit(
          query: query,
          args: DB::MetadataValueConverter.arg_to_log(args),
          time: (time.nanoseconds / 1000000).round(1)
        )
        res
      end

      def log_query(query : String, &)
        time = Time.monotonic
        res = yield
        time = Time.monotonic - time
        Config.logger.debug &.emit(query: query, time: (time.nanoseconds / 1000000).round(1))
        res
      end

      # Returns whether index for the *table` with *name* or *fields* exists.
      #
      # ```
      # # Check an index exists
      # adapter.index_exists?(:suppliers, :company_id)
      #
      # # Check an index on multiple columns exists
      # adapter.index_exists?(:suppliers, [:company_id, :company_type])
      #
      # # Check an index with a custom name exists
      # adapter.index_exists?(:suppliers, "idx_company_id")
      # ```
      def index_exists?(table, fields : Array)
        index_name = Migration::TableBuilder::CreateIndex.generate_index_name(table, fields, nil)
        index_exists?(table, index_name)
      end

      def parse_query(q : String, args : ArgsType)
        sql_generator.parse_query(q, args)
      end

      def parse_query(q : String)
        sql_generator.parse_query(q)
      end

      def coerce_database_value(value, target_class)
        value
      end

      def max_bind_vars_count
        Config.instance.max_bind_vars_count || self.class.default_max_bind_vars_count
      end

      def create_database
        command_interface.create_database
      end

      def generate_schema
        command_interface.generate_schema
      end

      def load_schema
        command_interface.load_schema
      end

      def drop_database
        command_interface.drop_database
      end

      def database_exists?
        command_interface.database_exists?
      end

      # Yields to block connection to the database main schema.
      def db_connection(&)
        DB.open(connection_string(:root)) do |db|
          yield(db)
        end
      rescue e
        puts e
        raise e
      end

      # Generates name for join table.
      def self.join_table_name(table1 : String | Symbol, table2 : String | Symbol)
        [table1.to_s, table2.to_s].sort.join("_")
      end

      # Generates foreign key name for given tables.
      def self.foreign_key_name(from_table, to_table = nil, column = nil, name : String? = nil) : String
        column_name = Migration::TableBuilder::CreateForeignKey.column_name(to_table, column)
        Migration::TableBuilder::CreateForeignKey.foreign_key_name(from_table, column_name, name)
      end

      def connection_string(type : ConnectionType)
        URI.new(
          self.class.protocol,
          config.host,
          config.port.try(&.>(0)) ? config.port : nil,
          type.db? ? config.db : "",
          connection_query,
          config.user.blank? ? nil : config.user,
          config.password && !config.password.empty? ? config.password : nil
        ).to_s
      end

      # filter out value; should be refactored
      def self.t(field : Nil)
        "NULL"
      end

      def self.t(field : String)
        "'" + field + "'"
      end

      def self.t(field)
        field
      end

      # migration ========================

      def ready_to_migrate!
        return if table_exists?(Migration::Version.table_name)

        tb = Migration::TableBuilder::CreateTable.new(self, Migration::Version.table_name)
        tb.string(:version, {:size => 17, :null => false})
        tb.process
      end

      def query_array(_query : String, klass : T.class, field_count : Int32 = 1) forall T
        result = [] of Array(T)
        query(_query) do |rs|
          rs.each do
            temp = [] of T
            field_count.times do
              temp << rs.read(T)
            end
            result << temp
          end
        end
        result
      end

      abstract def command_interface
      abstract def schema_processor
      abstract def sql_generator

      # Check whether view with given *name* exists.
      #
      # ```
      # adapter.view_exists?(:youth_contacts)
      # ```
      abstract def view_exists?(name) : Bool

      abstract def insert(obj : Model::Base)

      # Returns where table with given *table* name exists.
      #
      # ```
      # adapter.table_exists?(:developers)
      # ```
      abstract def table_exists?(table)

      # Checks to see if a foreign key exists on a table for a given foreign key definition.
      #
      # ```
      # # Checks to see if a foreign key exists.
      # adapter.foreign_key_exists?(:accounts, :branches)
      #
      # # Checks to see if a foreign key on a specified column exists.
      # adapter.foreign_key_exists?(:accounts, column: :owner_id)
      #
      # # Checks to see if a foreign key with a custom name exists.
      # adapter.foreign_key_exists?(:accounts, name: "special_fk_name")
      # ```
      abstract def foreign_key_exists?(from_table, to_table = nil, column = nil, name : String? = nil) : Bool

      abstract def index_exists?(table, name : String)

      # Returns whether column of *table* with *name* exists.
      #
      # ```
      # # Check a column exists
      # column_exists?(:suppliers, :name)
      # ```
      abstract def column_exists?(table, name)

      # Translates symbol data type name to database-specific data type.
      abstract def translate_type(name)
      abstract def default_type_size(name)
      abstract def table_column_count(table)
      abstract def tables_column_count(tables : Array(String))
      abstract def with_table_lock(table : String, type : String = "default", &block : DB::Transaction -> Void)
      abstract def explain(q)

      def refresh_materialized_view(name)
        raise AbstractMethod.new(:refresh_materialized_view, self.class)
      end

      # private ===========================

      private def connection_query
        URI::Params.build do |form|
          {% begin %}
            {% for arg in Config::CONNECTION_URI_PARAMS %}
              form.add("{{arg.id}}", config.{{arg.id}}.to_s) unless config.{{arg.id}}.to_s.empty?
            {% end %}
          {% end %}
        end
      end

      private def model_escaped_bulk_insert(collection : Array, klass, fields : Array)
        values = extract_attributes(collection, klass, fields)
        exec(sql_generator.bulk_insert(klass.table_name, fields, values))
      end

      private def model_prepared_statement_bulk_insert(collection : Array, klass, fields : Array)
        values = collection.flat_map(&.arguments_to_insert[:args])
        parsed_query = parse_query(
          sql_generator.bulk_insert(klass.table_name, fields, collection.size),
          values
        )

        exec(*parsed_query)
      end

      private def extract_attributes(collection : Array, _klass, _fields : Array)
        collection.map(&.arguments_to_insert[:args])
      end
    end
  end
end
