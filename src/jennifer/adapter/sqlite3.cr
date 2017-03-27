require "sqlite3"

module Jennifer
  module Adapter
    class Sqlite3 < Base
      include Support

      TYPE_TRANSLATIONS = {
        :int    => "int",
        :string => "varchar",
        :bool   => "bool",
        :text   => "text",
      }

      def translate_type(name)
        TYPE_TRANSLATIONS[name]
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

      # overrides ==========================

      def transaction(&block)
        raise "Not supported yet"
      end

      def table_exist?(table)
        v = scalar "
          SELECT COUNT(*)
          FROM sqlite_master
          WHERE type='table' AND name='#{table}"
        v == 1
      end

      def self.result_to_array(rs)
        a = [] of DB::Any | Int16 | Int8
        rs.column_count.times do
          temp = rs.read
          if temp.is_a?(Int8)
            temp = (temp == 1i8).as(Bool)
          end
          a << temp
        end
        a
      end

      def self.result_to_hash(rs)
        h = {} of String => DB::Any | Int16 | Int8
        rs.column_count.times do |col|
          col_name = rs.column_name(col)
          h[col_name] = rs.read
          if h[col_name].is_a?(Int8)
            h[col_name] = (h[col_name] == 1i8).as(Bool)
          end
        end
        h
      end

      def self.table_row_hash(rs)
        raise "Not supported"
      end

      def self.drop_database
        File.delete(Config.db) if File.exists?(Config.db)
      end

      def self.create_database
        File.new(Config.db) if File.exists?(Config.db)
      end
    end
  end

  macro after_hook

  end
end

require "./sqlite3/result_set"

::Jennifer::Adapter.register_adapter("sqlite3", ::Jennifer::Adapter::Sqlite3)
