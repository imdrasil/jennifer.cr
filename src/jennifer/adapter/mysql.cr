require "mysql"
require "./base"
require "./request_methods"

module Jennifer
  alias DBAny = DB::Any | Int16 | Int8 | JSON::Any

  module Adapter
    class Mysql < Base
      include RequestMethods

      TYPE_TRANSLATIONS = {
        :integer    => "int",
        :string     => "varchar",
        :bool       => "bool",
        :text       => "text",
        :float      => "float",
        :double     => "double",
        :short      => "SMALLINT",
        :timestamp  => "timestamp",
        :date_time  => "datetime",
        :blob       => "blob",
        :var_string => "varstring",
        :json       => "json",
      }

      DEFAULT_SIZES = {
        :string => 254,
      }

      def translate_type(name : Symbol)
        TYPE_TRANSLATIONS[name]
      rescue e : KeyError
        raise BaseException.new("Unknown data alias #{name}")
      end

      def default_type_size(name)
        DEFAULT_SIZES[name]?
      end

      def table_exist?(table)
        v = scalar "
          SELECT COUNT(*)
          FROM information_schema.TABLES
          WHERE (TABLE_SCHEMA = '#{Config.db}') AND (TABLE_NAME = '#{table}')"
        v == 1
      end

      def index_exists?(table, name)
        v = scalar "
          SELECT COUNT(*)
          from information_schema.statistics
          WHERE  table_name = '#{table}' AND index_name = '#{name}'"
        v == 1
      end

      def column_exists?(table, name)
        v = scalar "SELECT COUNT(*)
          FROM information_schema.COLUMNS
          WHERE TABLE_NAME = '#{table}'
          AND COLUMN_NAME = '#{name}'"
        v == 1
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

  macro after_load_hook

  end
end

require "./mysql/result_set"
require "./mysql/type"

::Jennifer::Adapter.register_adapter("mysql", ::Jennifer::Adapter::Mysql)
