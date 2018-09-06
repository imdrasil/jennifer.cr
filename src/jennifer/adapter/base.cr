require "db"
require "ifrit"
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

      alias ArgType = DBAny
      alias ArgsType = Array(ArgType)

      module AbstractClassMethods
        abstract def command_interface
      end

      extend AbstractClassMethods

      getter db : DB::Database

      def initialize
        @db = DB.open(Base.connection_string(:db))
      end

      def self.build
        a = new
        a
      end

      def prepare
        ::Jennifer::Model::Base.models.each(&.actual_table_field_count)
      end

      def exec(_query, args : ArgsType = [] of DBAny)
        time = Time.monotonic
        res = with_connection { |conn| conn.exec(_query, args) }
        time = Time.monotonic - time
        Config.logger.debug { regular_query_message(time, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : DB::Error
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def query(_query, args : ArgsType = [] of DBAny)
        time = Time.monotonic
        res = with_connection { |conn| conn.query(_query, args) { |rs| time = Time.monotonic - time; yield rs } }
        Config.logger.debug { regular_query_message(time, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : DB::Error
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def scalar(_query, args : ArgsType = [] of DBAny)
        time = Time.monotonic
        res = with_connection { |conn| conn.scalar(_query, args) }
        time = Time.monotonic - time
        Config.logger.debug { regular_query_message(time, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : DB::Error
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def truncate(klass : Class)
        truncate(klass.table_name)
      end

      def truncate(table_name : String)
        exec sql_generator.truncate(table_name)
      end

      def delete(query : QueryBuilder::Query)
        args = query.select_args
        exec *sql_generator.delete(query)
      end

      def exists?(query : QueryBuilder::Query)
        args = query.select_args
        scalar(*sql_generator.exists(query)) == 1
      end

      def count(query : QueryBuilder::Query)
        args = query.select_args
        scalar(*sql_generator.count(query)).as(Int64).to_i
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
            klass.all.order({klass.primary => :desc}).limit(collection.size).pluck(:id).reverse_each.each_with_index do |id, i|
              collection[i].init_primary_field(id.as(Int))
            end
          end
        end
        collection
      end

      def bulk_insert(table : String, fields : Array(String), values : Array(ArgsType)) : Nil
        return if values.empty?
        with_table_lock(table) do
          flat_values = values.flatten
          exec(*parse_query(sql_generator.bulk_insert(table, fields, values.size), flat_values))
        end
        nil
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

      def self.db_connection
        DB.open(connection_string) do |db|
          yield(db)
        end
      rescue e
        puts e
        raise e
      end

      def self.join_table_name(table1 : String | Symbol, table2 : String | Symbol)
        [table1.to_s, table2.to_s].sort.join("_")
      end

      # Generates foreign key name for given tables.
      def self.foreign_key_name(table1, table2)
        "fk_cr_#{join_table_name(table1, table2)}"
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

      def self.extract_arguments(hash : Hash) : NamedTuple(args: ArgsType, fields: Array(String))
        args = [] of DBAny
        fields = [] of String
        hash.each do |key, value|
          fields << key.to_s
          args << value
        end
        {args: args, fields: fields}
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
        schema_processor.build_create_table(Migration::Version.table_name) do |t|
          t.string(:version, {:size => 17, :null => false})
        end
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
      abstract def view_exists?(name, silent = true)
      abstract def update(obj)
      abstract def update(q, h)
      abstract def insert(obj)
      abstract def table_exists?(table)
      abstract def index_exists?(table, name)
      abstract def column_exists?(table, name)
      abstract def translate_type(name)
      abstract def default_type_size(name)
      abstract def table_column_count(table)
      abstract def with_table_lock(table : String, type : String = "default", &block)

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
