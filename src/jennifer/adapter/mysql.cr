require "mysql"
require "./base"
require "./request_methods"

module Jennifer
  module Adapter
    class Mysql < Base
      include RequestMethods

      TYPE_TRANSLATIONS = {
        :int    => "int",
        :string => "varchar",
        :bool   => "bool",
        :text   => "text",
      }

      def type_translations
        TYPE_TRANSLATIONS
      end

      def parse_query(query, args)
        arr = [] of String
        args.each do
          arr << "?"
        end
        query % arr
      end

      def parse_query(query)
        query
      end

      def table_exist?(table)
        v = scalar "
          SELECT COUNT(*)
          FROM information_schema.TABLES
          WHERE (TABLE_SCHEMA = '#{Config.db}') AND (TABLE_NAME = '#{table}')"
        v == 1
      end

      # is enough unsafe. prefer to use `transaction` with block
      # def transaction(autocommit : Bool = true)
      #  @connection.start_transaction
      #  # exec autocommit ? "BEGIN" : "START TRANSACTION"
      # end

      # is unsafe
      # def commit
      #  @connection.commit_transaction
      #  # exec "COMMIT"
      # end

      # is unsafe
      # def rollback
      #  @connection.rollback_transaction
      #  # exec "ROLLBACK"
      # end
    end

    def table_row_hash(rs)
      h = {} of String => Hash(String, DB::Any | Int16 | Int8)
      rs.columns.each do |col|
        h[col.table] ||= {} of String => DB::Any | Int16 | Int8
        h[col.table][col.name] = rs.read
        if h[col.table][col.name].is_a?(Int8)
          h[col.table][col.name] = h[col.table][col.name] == 1i8
        end
      end
      h
    end
  end
end

::Jennifer::Adapter.register_adapter("mysql", ::Jennifer::Adapter::Mysql)

class DB::ResultSet
  getter column_index

  @column_index = 0
  @columns = [] of MySql::ColumnSpec

  def current_column
    @columns[@column_index]
  end

  def current_column_name
    column_name(@column_index)
  end

  def columns
    @columns
  end
end
