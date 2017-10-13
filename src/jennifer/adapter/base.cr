require "db"
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

      TICKS_PER_MICROSECOND = 10
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
        time = Time.now.ticks
        res = with_connection { |conn| conn.exec(_query, args) }
        time = Time.now.ticks - time
        Config.logger.debug { regular_query_message(time / TICKS_PER_MICROSECOND, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def query(_query, args = [] of DB::Any)
        time = Time.now.ticks
        res = with_connection { |conn| conn.query(_query, args) { |rs| time = Time.now.ticks - time; yield rs } }
        Config.logger.debug { regular_query_message(time / TICKS_PER_MICROSECOND, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def scalar(_query, args = [] of DB::Any)
        time = Time.now.ticks
        res = with_connection { |conn| conn.scalar(_query, args) }
        time = Time.now.ticks - time
        Config.logger.debug { regular_query_message(time / TICKS_PER_MICROSECOND, _query, args) }
        res
      rescue e : BaseException
        BadQuery.prepend_information(e, _query, args)
        raise e
      rescue e : Exception
        raise BadQuery.new(e.message, _query, args)
      end

      def parse_query(q, args)
        SqlGenerator.parse_query(q, args.size)
      end

      def parse_query(q)
        SqlGenerator.parse_query(q)
      end

      def truncate(klass : Class)
        truncate(klass.table_name)
      end

      def truncate(table_name : String)
        exec "TRUNCATE #{table_name}"
      end

      def delete(query : QueryBuilder::Query)
        args = query.select_args
        exec SqlGenerator.delete(query), args
      end

      def exists?(query)
        args = query.select_args
        scalar(SqlGenerator.exists(query), args) == 1
      end

      def count(query)
        args = query.select_args
        scalar(SqlGenerator.count(query), args).as(Int64).to_i
      end

      def self.db_connection
        DB.open(connection_string) do |db|
          yield(db)
        end
      rescue e
        puts e
        raise e
      end

      def self.join_table_name(table1, table2)
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
          [
            {% for arg in Config::CONNECTION_URI_PARAMS %}
              "{{arg.id}}=#{Config.{{arg.id}}}"
            {% end %},
          ].join(",", s)
        end
      end

      def self.extract_arguments(hash)
        args = [] of DBAny
        fields = [] of String
        hash.each do |key, value|
          fields << key.to_s
          args << value
        end
        {args: args, fields: fields}
      end

      def self.arg_replacement(arr)
        escape_string(arr.size)
      end

      def self.escape_string(size = 1)
        SqlGenerator.escape_string(size)
      end

      def self.drop_database
        db_connection do |db|
          db.exec "DROP DATABASE #{Config.db}"
        end
      end

      def self.create_database
        db_connection do |db|
          puts db.exec "CREATE DATABASE #{Config.db}"
        end
      end

      def self.generate_schema
        raise "Not implemented"
      end

      def self.load_schema
        raise "Not implemented"
      end

      # filter out value; should be refactored
      def self.t(field)
        case field
        when Nil
          "NULL"
        when String
          "'" + field + "'"
        else
          field
        end
      end

      # migration ========================

      def ready_to_migrate!
        return if table_exists?(Migration::Base::TABLE_NAME)
        tb = Migration::TableBuilder::CreateTable.new(Migration::Base::TABLE_NAME)
        tb.integer(:id, {:primary => true, :auto_increment => true})
          .string(:version, {:size => 17})
        create_table(tb)
      end

      def rename_table(old_name, new_name)
        exec "ALTER TABLE #{old_name.to_s} RENAME #{new_name.to_s}"
      end

      def add_index(table, name, options)
        query = String.build do |s|
          s << "CREATE "

          s << index_type_translate(options[:type]) if options[:type]?

          s << "INDEX " << name << " ON " << table << "("
          fields = options.as(Hash)[:fields].as(Array)
          fields.each_with_index do |f, i|
            s << "," if i != 0
            s << f
            s << "(" << options[:length].as(Hash)[f] << ")" if options[:length]? && options[:length].as(Hash)[f]?
            s << " " << options[:order].as(Hash)[f].to_s.upcase if options[:order]? && options[:order].as(Hash)[f]?
          end
          s << ")"
        end
        exec query
      end

      def drop_index(table, name)
        exec "DROP INDEX #{name} ON #{table}"
      end

      def drop_column(table, name)
        exec "ALTER TABLE #{table} DROP COLUMN #{name}"
      end

      def add_column(table, name, opts)
        query = String.build do |s|
          s << "ALTER TABLE " << table << " ADD COLUMN "
          column_definition(name, opts, s)
        end

        exec query
      end

      def change_column(table, old_name, new_name, opts)
        query = String.build do |s|
          s << "ALTER TABLE " << table << " CHANGE COLUMN " << old_name << " "
          column_definition(new_name, opts, s)
        end

        exec query
      end

      def drop_table(builder : Migration::TableBuilder::DropTable)
        exec "DROP TABLE #{builder.name}"
      end

      def create_table(builder : Migration::TableBuilder::CreateTable)
        buffer = String.build do |s|
          s << "CREATE TABLE " << builder.name << " ("
          builder.fields.each_with_index do |(name, options), i|
            s << ", " if i != 0
            column_definition(name, options, s)
          end
          s << ")"
        end
        exec buffer
      end

      def create_enum(name, options)
        raise BaseException.new("Current adapter doesn't support this method.")
      end

      def drop_enum(name, options)
        raise BaseException.new("Current adapter doesn't support this method.")
      end

      def change_enum(name, options)
        raise BaseException.new("Current adapter doesn't support this method.")
      end

      def create_view(name, query, silent = true)
        buff = String.build do |s|
          s << "CREATE "
          s << "OR REPLACE " if silent
          s << "VIEW " << name << " AS " << SqlGenerator.select(query)
        end
        args = query.select_args
        exec parse_query(buff, args), args
      end

      def drop_view(name, silent = true)
        buff = String.build do |s|
          s << "DROP VIEW "
          s << "IF EXISTS " if silent
          s << name
        end
        exec buff
      end

      abstract def view_exists?(name, silent = true)
      abstract def update(obj)
      abstract def update(q, h)
      abstract def insert(obj)
      abstract def distinct(q, c, t)
      abstract def table_exists?(table)
      abstract def index_exists?(table, name)
      abstract def column_exists?(table, name)
      abstract def translate_type(name)
      abstract def default_type_size(name)
      abstract def table_column_count(table)

      # private ===========================

      private def index_type_translate(name)
        case name
        when :unique, :uniq
          "UNIQUE "
        when :fulltext
          "FULLTEXT "
        when :spatial
          "SPATIAL "
        when nil
          " "
        else
          raise ArgumentError.new("Unknown index type: #{name}")
        end
      end

      private def column_definition(name, options, io)
        type = options[:serial]? ? "serial" : (options[:sql_type]? || translate_type(options[:type].as(Symbol)))
        size = options[:size]? || default_type_size(options[:type])
        io << name << " " << type
        io << "(#{size})" if size
        if options[:type] == :enum
          io << " ("
          options[:values].as(Array).each_with_index do |e, i|
            io << ", " if i != 0
            io << "'#{e.as(String | Symbol)}'"
          end
          io << ") "
        end
        if options.has_key?(:null)
          if options[:null]
            io << " NULL"
          else
            io << " NOT NULL"
          end
        end
        io << " PRIMARY KEY" if options[:primary]?
        io << " DEFAULT #{self.class.t(options[:default])}" if options[:default]?
        io << " AUTO_INCREMENT" if options[:auto_increment]?
      end

      private def regular_query_message(ms, query : String, args : Array)
        args.empty? ? "#{ms} µs #{query}" : "#{ms} µs #{query} | #{args.inspect}"
      end

      private def regular_query_message(ms, query : String, arg = nil)
        arg ? "#{ms} µs #{query} | #{arg}" : "#{ms} µs #{query}"
      end
    end
  end
end
