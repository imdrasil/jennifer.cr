require "mysql"
require "./base"

require "./mysql/sql_generator"
require "./mysql/command_interface"
require "./mysql/schema_processor"

module Jennifer
  module Mysql
    class Adapter < Adapter::Base
      include ::Jennifer::Adapter::RequestMethods

      alias EnumType = String

      TYPE_TRANSLATIONS = {
        :bool => "bool",
        :enum => "enum",

        :bigint  => "bigint",   # Int64
        :integer => "int",      # Int32
        :short   => "SMALLINT", # Int16
        :tinyint => "TINYINT",  # Int8

        :float  => "float",  # Float32
        :double => "double", # Float64

        :decimal => "decimal", # Float64

        :string  => "varchar",
        :varchar => "varchar",
        :text    => "text",

        :timestamp => "datetime", # "timestamp",
        :date_time => "datetime",
        :date      => "date",

        :blob => "blob",
        :json => "json",
      }

      DEFAULT_SIZES = {
        :string  => 254,
        :varchar => 254,
      }

      # NOTE: ATM is not used
      TABLE_LOCK_TYPES = {
        "r"       => "READ",
        "rl"      => "READ LOCAL",
        "w"       => "WRITE",
        "lpw"     => "LOW_PRIORITY WRITE",
        "default" => "READ", # "r"
      }

      def sql_generator
        SQLGenerator
      end

      def schema_processor
        @schema_processor ||= SchemaProcessor.new(self)
      end

      def translate_type(name)
        TYPE_TRANSLATIONS[name]
      rescue e : KeyError
        raise BaseException.new("Unknown data alias #{name}")
      end

      def default_type_size(name)
        DEFAULT_SIZES[name]?
      end

      def table_column_count(table)
        if table_exists?(table)
          Query["information_schema.COLUMNS", self].where do
            (_table_name == table) & (_table_schema == config.db)
          end.count
        else
          -1
        end
      end

      def tables_column_count(tables)
        Query["information_schema.COLUMNS", self]
          .where { _table_name.in(tables) & (_table_schema == config.db) }
          .group(:table_name)
          .select { [_table_name.alias("table_name"), count.alias("count")] }
      end

      def table_exists?(table)
        Query["information_schema.TABLES", self]
          .where { (_table_schema == config.db) & (_table_name == table) }
          .exists?
      end

      def view_exists?(name) : Bool
        Query["information_schema.TABLES", self]
          .where { (_table_schema == config.db) & (_table_type == "VIEW") & (_table_name == name) }
          .exists?
      end

      def index_exists?(table, name : String)
        Query["information_schema.statistics", self].where do
          (_table_name == table) &
            (_index_name == name) &
            (_table_schema == config.db)
        end.exists?
      end

      def column_exists?(table, name)
        Query["information_schema.COLUMNS", self].where do
          (_table_name == table) &
            (_column_name == name) &
            (_table_schema == config.db)
        end.exists?
      end

      def foreign_key_exists?(from_table, to_table = nil, column = nil, name : String? = nil) : Bool
        name = self.class.foreign_key_name(from_table, to_table, column, name)
        Query["information_schema.KEY_COLUMN_USAGE", self]
          .where { and(_constraint_name == name, _table_schema == config.db) }
          .exists?
      end

      def with_table_lock(table : String, type : String = "default", &)
        transaction do |t|
          config.logger.debug do
            "MySQL doesn't support manual locking table from prepared statement. " \
            "Instead of this only transaction was started."
          end
          yield t
        end
      end

      def explain(q)
        body = sql_generator.explain(q)
        args = q.sql_args
        plan = [] of Array(String)
        query(*parse_query(body, args)) do |rs|
          rs.each do
            row = %w()
            12.times do
              temp = rs.read
              row << (temp.nil? ? "NULL" : temp.to_s)
            end
            plan << row
          end
        end

        format_explain_query(plan)
      end

      def command_interface
        @command_interface ||= CommandInterface.new(config)
      end

      def self.default_max_bind_vars_count
        32766
      end

      def create_database
        db_connection do |db|
          db.exec "CREATE DATABASE #{config.db}"
        end
      end

      def drop_database
        db_connection do |db|
          db.exec "DROP DATABASE #{config.db}"
        end
      end

      def database_exists? : Bool
        db_connection do |db|
          db.scalar <<-SQL,
            SELECT EXISTS(
              SELECT 1
              FROM INFORMATION_SCHEMA.SCHEMATA
              WHERE SCHEMA_NAME = ?
            )
          SQL
            config.db
        end == 1
      end

      def self.protocol : String
        "mysql"
      end

      def read_column(rs, column : MySql::ColumnSpec)
        if column.column_type == MySql::Type::Tiny && column.column_length == 1u32
          (rs.read.as(DBAny) == 1i8).as(Bool)
        else
          super
        end
      end

      private def format_explain_query(plan : Array)
        headers = %w(id select_type table partitions type possible_keys key key_len ref rows filtered Extra)
        column_sizes = headers.map(&.size)
        plan.each do |row|
          row.each_with_index do |cell, column_i|
            cell_size = cell.size
            column_sizes[column_i] = cell_size if cell_size > column_sizes[column_i]
          end
        end

        String.build do |io|
          format_table_row(io, headers, column_sizes)

          io << "\n"
          io << column_sizes.map { |size| "-" * size }.join(" | ")
          io << "\n"

          plan.each_with_index do |row, row_i|
            io << "\n" if row_i != 0
            format_table_row(io, row, column_sizes)
          end
        end
      end

      private def format_table_row(io, row, column_sizes)
        row.each_with_index do |cell, i|
          io << " | " if i != 0
          io << cell.ljust(column_sizes[i])
        end
      end
    end
  end
end

require "./mysql/result_set"
require "./mysql/type"

::Jennifer::Adapter.register_adapter("mysql", ::Jennifer::Mysql::Adapter)
