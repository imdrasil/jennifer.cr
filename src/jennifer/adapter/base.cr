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

      include Transactions
      include ResultParsers
      include RequestMethods

      alias ArgsType = Array(DBAny)

      module AbstractClassMethods
        abstract def command_interface
      end

      extend AbstractClassMethods

      getter db : DB::Database

      def initialize
        @db = DB.open(self.class.connection_string(:db))
      end

      def self.build
        new
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
            model.actual_table_field_count = count
          end
        end
      end

      def exec(query : String, args : ArgsType = [] of DBAny)
        time = Time.monotonic
        res = with_connection { |conn| conn.exec(query, args: args) }
        time = Time.monotonic - time
        Config.logger.debug { regular_query_message(time, query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, query, args)
        raise e
      rescue e : DB::Error
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, query, args)
      end

      def query(query : String, args : ArgsType = [] of DBAny)
        time = Time.monotonic
        res = with_connection { |conn| conn.query(query, args: args) { |rs| time = Time.monotonic - time; yield rs } }
        Config.logger.debug { regular_query_message(time, query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, query, args)
        raise e
      rescue e : DB::Error
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, query, args)
      end

      def scalar(query : String, args : ArgsType = [] of DBAny)
        time = Time.monotonic
        res = with_connection { |conn| conn.scalar(query, args: args) }
        time = Time.monotonic - time
        Config.logger.debug { regular_query_message(time, query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, query, args)
        raise e
      rescue e : DB::Error
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
        scalar(*parse_query(sql_generator.count(query), query.sql_args)).as(Int64).to_i
      end

      def bulk_insert(collection : Array(Model::Base))
        return collection if collection.empty?

        klass = collection[0].class
        fields = collection[0].arguments_to_insert[:fields]
        values = collection.flat_map(&.arguments_to_insert[:args])
        parsed_query = parse_query(sql_generator.bulk_insert(klass.table_name, fields, collection.size), values)

        with_table_lock(klass.table_name) do
          exec(*parsed_query)
          if klass.primary_auto_incrementable?
            klass.all.order(klass.primary.desc).limit(collection.size).pluck(:id).reverse_each.each_with_index do |id, i|
              collection[i].init_primary_field(id.as(Int))
            end
          end
        end
        collection
      end

      def bulk_insert(table : String, fields : Array(String), values : Array(ArgsType))
        return if values.empty?

        with_table_lock(table) do
          flat_values = values.flatten
          exec(*parse_query(sql_generator.bulk_insert(table, fields, values.size), flat_values))
        end
      end

      def upsert(table : String, fields : Array(String), values : Array(ArgsType), unique_fields, on_conflict : Hash)
        query = sql_generator.insert_on_duplicate(table, fields, values.size, unique_fields, on_conflict)
        args = [] of DBAny
        values.each { |row| args.concat(row) }
        on_conflict.each { |_, value| add_field_assign_arguments(args, value) }

        exec(*parse_query(query, args))
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

      def self.create_database
        command_interface.create_database
      end

      def self.generate_schema
        command_interface.generate_schema
      end

      def self.load_schema
        command_interface.load_schema
      end

      def self.drop_database
        command_interface.drop_database
      end

      def self.database_exists?
        command_interface.database_exists?
      end

      # Yields to block connection to the database main schema.
      def self.db_connection
        DB.open(connection_string) do |db|
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

      def self.connection_string(*options)
        auth_part = Config.user
        auth_part += ":#{Config.password}" if Config.password && !Config.password.empty?

        host_part = Config.host
        host_part += ":#{Config.port}" if Config.port.try(&.>(0))

        String.build do |s|
          s << Config.adapter << "://" << auth_part << "@" << host_part
          s << "/" << Config.db if options.includes?(:db)
          s << "?"
          {% begin %}
          [
            {% for arg in Config::CONNECTION_URI_PARAMS %}
              "{{arg.id}}=#{Config.{{arg.id}}}",
            {% end %}
          ].join("&", s)
          {% end %}
        end
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
        tb.integer(:id, { :primary => true, :auto_increment => true })
        tb.string(:version, { :size => 17, :null => false })
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

      abstract def schema_processor
      abstract def sql_generator

      # Check whether view with given *name* exists.
      #
      # ```
      # adapter.view_exists?(:youth_contacts)
      # ```
      abstract def view_exists?(name) : Bool

      abstract def update(obj)
      abstract def update(q, h)
      abstract def insert(obj)

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
      abstract def with_table_lock(table : String, type : String = "default", &block)
      abstract def explain(q)

      def refresh_materialized_view(name)
        raise AbstractMethod.new(:refresh_materialized_view, self.class)
      end

      # private ===========================

      private def regular_query_message(time : Time::Span, query : String, args : Array)
        ms = time.nanoseconds / 1000
        args.empty? ? "#{ms} µs #{query}" : "#{ms} µs #{query} | #{args.inspect}"
      end

      private def regular_query_message(time : Time::Span, query : String, arg = nil)
        ms = time.nanoseconds / 1000
        arg ? "#{ms} µs #{query} | #{arg}" : "#{ms} µs #{query}"
      end
    end
  end
end
