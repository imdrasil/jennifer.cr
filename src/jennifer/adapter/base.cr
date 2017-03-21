require "db"

module Jennifer
  module Adapter
    abstract class Base
      @connection : DB::Database

      getter connection

      # delegate exec, query, scalar, to: @connection

      def initialize
        @connection = DB.open(Base.connection_string(:db))
      end

      def exec(_query, args = [] of DB::Any)
        @connection.exec(_query, args)
      rescue e : Exception
        raise BadQuery.new(e.message, _query)
      end

      def query(_query, args = [] of DB::Any)
        @connection.query(_query, args)
      rescue e : Exception
        raise BadQuery.new(e.message, _query)
      end

      def query(_query, args = [] of DB::Any)
        @connection.query(_query, args) { |rs| yield rs }
      rescue e : Exception
        raise BadQuery.new(e.message, _query)
      end

      def scalar(_query, args = [] of DB::Any)
        @connection.scalar(_query, args)
      rescue e : Exception
        raise BadQuery.new(e.message, _query)
      end

      def transaction
        result = false
        @connection.transaction do |tx|
          begin
            result = yield(tx)
            tx.rollback unless result
          rescue
            tx.rollback
          end
        end
        result
      end

      def truncate(klass : Class)
        truncate(klass.table_name)
      end

      def truncate(table_name : String)
        exec "TRUNCATE #{table_name}"
      end

      def delete(query : QueryBuilder::Query)
        body = String.build do |s|
          query.from_clause(s)
          s << query.body_section
        end
        args = query.select_args
        exec "DELETE #{parse_query(body, args)}", args
      end

      def exists?(query)
        args = query.select_args
        body = String.build do |s|
          s << "SELECT EXISTS(SELECT 1 "
          query.from_clause(s)
          s << parse_query(query.body_section, args) << ")"
        end
        scalar(body, args) == 1
      end

      # TODO: refactore this to use regular request
      def count(query)
        body = String.build do |s|
          query.from_clause(s)
          s << query.body_section
        end
        args = query.select_args
        scalar("SELECT COUNT(*) #{parse_query(body, args)}", args).as(Int64).to_i
      end

      def self.db_connection
        DB.open(connection_string) do |db|
          yield(db)
        end
      rescue e
        puts e
      end

      def self.connection_string(*options)
        auth_part = Config.user
        auth_part += ":#{Config.password}" if Config.password && !Config.password.empty?
        str = "#{Config.adapter}://#{auth_part}@#{Config.host}"
        str += "/" + Config.db if options.includes?(:db)
        str
      end

      def self.extract_arguments(hash)
        args = [] of DB::Any
        fields = [] of String
        hash.each do |key, value|
          fields << key.to_s
          args << value
        end
        {args: args, fields: fields}
      end

      # converts single ResultSet to hash
      abstract def result_to_hash(rs)

      # converts single ResultSet which contains several tables
      abstract def table_row_hash(rs)

      def result_to_array(rs)
        a = [] of DB::Any | Int16 | Int8
        rs.columns.each do |col|
          temp = rs.read
          if temp.is_a?(Int8)
            temp = (temp == 1i8).as(Bool)
          end
          a << temp
        end
        a
      end

      def self.arg_replacement(arr)
        escape_string(arr.size)
      end

      def self.escape_string(size = 1)
        case size
        when 1
          "%s"
        when 2
          "%s, %s"
        when 3
          "%s, %s, %s"
        else
          size.times.map { "%s" }.join(", ")
        end
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
        return if table_exist?(Migration::Base::TABLE_NAME)
        tb = Migration::TableBuilder::CreateTable.new(Migration::Base::TABLE_NAME)
        tb.integer(:id, {primary: true, auto_increment: true})
          .string(:version, {size: 18})
        create_table(tb)
      end

      def change_table(builder : Migration::TableBuilder::ChangeTable)
        table_name = builder.name
        builder.fields.each do |k, v|
          case k
          when :rename
            exec "ALTER TABLE #{table_name} RENAME #{v[:name]}"
            table_name = v[:name]
          end
        end
      end

      def drop_table(builder : Migration::TableBuilder::DropTable)
        exec "DROP TABLE #{builder.name} IF EXISTS"
      end

      def create_table(builder : Migration::TableBuilder::CreateTable)
        buffer = "CREATE TABLE #{builder.name.to_s} ("
        builder.fields.each do |name, options|
          type = options[:serial]? ? "serial" : options[:sql_type]? || type_translations[options[:type]]
          suffix = ""
          suffix += "(#{options[:size]})" if options[:size]?
          suffix += " NOT NULL" if options[:null]?
          suffix += " PRIMARY KEY" if options[:primary]?
          suffix += " DEFAULT #{self.class.t(options[:default])}" if options[:default]?
          suffix += " AUTO_INCREMENT" if options[:auto_increment]?
          buffer += "#{name.to_s} #{type}#{suffix},"
        end
        exec buffer[0...-1] + ")"
      end

      abstract def update(obj)
      abstract def update(q, h)
      abstract def insert(obj)
      abstract def distinct(q, c, t)
      abstract def table_exist?(table)
      abstract def type_translations
      abstract def parse_query(query : QueryBuilder, args)
      abstract def parse_query(query)
    end
  end
end
