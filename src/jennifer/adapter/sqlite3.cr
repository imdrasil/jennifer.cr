require "sqlite3"
require "../adapter"
require "./sqlite3/sql_notation"
require "./sqlite3/schema_processor"

module Jennifer
  module Sqlite3
    class Adapter < Base
      alias EnumType = String

      TYPE_TRANSLATIONS = {
        :integer   => "integer",
        :bool      => "integer",
        :short     => "integer",
        :text      => "text",
        :string    => "text",
        :time      => "text",
        :timestamp => "text",
        :json      => "text",
        :float     => "real",
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

      def default_type_size(name); end

      # overrides ==========================

      def table_exists?(table)
        v = scalar "
          SELECT COUNT(*)
          FROM sqlite_master
          WHERE type='table' AND name='#{table}'"
        v == 1
      end

      def column_exists?(table, name)
        c = scalar "
          SELECT COUNT(*)
          FROM pragma_table_info('#{table}')
          WHERE colymn_name = '#{name}'"
        c == 1
      end

      def index_exists?(table, name)
        c = scalar "
          SELECT COUNT(*)
          FROM sys.indexes
          WHERE name='#{name}' AND object_id = OBJECT_ID('Schema.#{table}')"
        c == 1
      end

      def self.table_row_hash(rs)
        raise "Not supported"
      end

      def self.drop_database
        File.delete(db_path) if File.exists?(db_path)
      end

      def self.create_database
        File.new(db_path, "w") unless File.exists?(db_path)
      end

      def self.generate_schema
      end

      def self.load_schema
      end

      #
      # private
      #

      private def self.db_path
        File.join(Config.host, Config.db)
      end
    end
  end
end

require "./sqlite3/result_set"

::Jennifer::Adapter.register_adapter("sqlite3", ::Jennifer::Sqlite3::Adapter)
