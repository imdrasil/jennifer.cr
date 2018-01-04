require "db"
require "ifrit"
require "./shared/*"
require "./transactions"
require "./result_parsers"
require "./request_methods"

module Jennifer
  module Adapter
    abstract class Base
      include Transactions
      include ResultParsers
      include RequestMethods

      @db : DB::Database

      getter db

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

      def exec(_query, args = [] of DB::Any)
        time = Time.monotonic
        res = with_connection { |conn| conn.exec(_query, args) }
        time = Time.monotonic - time
        Config.logger.debug { regular_query_message(time, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def query(_query, args = [] of DB::Any)
        time = Time.monotonic
        res = with_connection { |conn| conn.query(_query, args) { |rs| time = Time.monotonic - time; yield rs } }
        Config.logger.debug { regular_query_message(time, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def scalar(_query, args : Array(DB::Any) = [] of DB::Any)
        time = Time.monotonic
        res = with_connection { |conn| conn.scalar(_query, args) }
        time = Time.monotonic - time
        Config.logger.debug { regular_query_message(time, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def parse_query(q : String, args)
        sql_generator.parse_query(q, args.size)
      end

      def parse_query(q : String)
        sql_generator.parse_query(q)
      end

      def truncate(klass : Class)
        truncate(klass.table_name)
      end

      def truncate(table_name : String)
        exec sql_generator.truncate(table_name)
      end

      def delete(query : QueryBuilder::Query)
        args = query.select_args
        exec sql_generator.delete(query), args
      end

      def exists?(query : QueryBuilder::Query)
        args = query.select_args
        scalar(sql_generator.exists(query), args) == 1
      end

      def count(query : QueryBuilder::Query)
        args = query.select_args
        scalar(sql_generator.count(query), args).as(Int64).to_i
      end

      def bulk_insert(collection : Array(Model::Base))
        return collection if collection.empty?
        klass = collection[0].class
        fields = collection[0].arguments_to_insert[:fields]
        values = collection.flat_map(&.arguments_to_insert[:args])
        parsed_query = parse_query(sql_generator.bulk_insert(klass.table_name, fields, collection.size), values)

        with_table_lock(klass.table_name) do
          exec(parsed_query, values)
          if klass.primary_auto_incrementable?
            klass.all.order({klass.primary => :desc}).limit(collection.size).pluck(:id).reverse_each.each_with_index do |id, i|
              collection[i].init_primary_field(id)
            end
          end
        end
        collection
      end

      def bulk_insert(table : String, fields : Array(String), values : Array(Array(DBAny))) : Nil
        return if values.empty?
        with_table_lock(table) do
          flat_values = values.flatten
          exec(parse_query(sql_generator.bulk_insert(table, fields, values.size), flat_values), flat_values)
        end
        nil
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

      def self.connection_string(*options)
        auth_part = Config.user
        auth_part += ":#{Config.password}" if Config.password && !Config.password.empty?

        host_part = Config.host
        host_part += Config.port.to_s if Config.port && Config.port > 0

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

      def self.extract_arguments(hash : Hash) : NamedTuple(args: Array(Jennifer::DBAny), fields: Array(String))
        args = [] of DBAny
        fields = [] of String
        hash.each do |key, value|
          fields << key.to_s
          args << value
        end
        {args: args, fields: fields}
      end

      def self.drop_database
        db_connection do |db|
          db.exec "DROP DATABASE #{Config.db}"
        end
      end

      def self.create_database
        db_connection do |db|
          db.exec "CREATE DATABASE #{Config.db}"
        end
      end

      def self.generate_schema
        raise AbstractMethod.new("generate_schema", self)
      end

      def self.load_schema
        raise AbstractMethod.new("load_schema", self)
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
        return if table_exists?(Migration::Base::TABLE_NAME)
        migration_processor.build_create_table(Migration::Base::TABLE_NAME) do |t|
          t.string(:version, {:size => 17})
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

      abstract def migration_processor
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
