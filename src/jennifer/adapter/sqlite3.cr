require "sqlite3"
require "../adapter"
require "./request_methods"
require "./sqlite3/sql_notation"

module Jennifer
  alias DBAny = DB::Any

  module Adapter
    alias EnumType = String

    class Sqlite3 < Base
      include RequestMethods

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

      def rename_table(old_name, new_name)
        exec "ALTER TABLE #{old_name.to_s} RENAME TO #{new_name.to_s}"
      end

      def drop_index(table, name)
        exec "DROP INDEX #{name}"
      end

      def change_column(table, old_name, new_name, opts)
        raise "ALTER COLUMN is not implemented yet. Take a look on this http://www.sqlite.org/faq.html#q11"
      end

      def drop_column(table, old_name, new_name, opts)
        raise "DROP COLUMN is not implemented yet. Take a look on this http://www.sqlite.org/faq.html#q11"
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

      private def column_definition(name, options, io)
        type = options[:sql_type]? || translate_type(options[:type].as(Symbol))
        size = options[:size]? || default_type_size(options[:type])
        io << name << " " << type
        io << "(#{size})" if size
        if options.key?(:null)
          if options[:null]
            io << " NULL"
          else
            io << " NOT NULL"
          end
        end
        io << " PRIMARY KEY" if options[:primary]?
        io << " DEFAULT #{self.class.t(options[:default])}" if options[:default]?
        io << " AUTOINCREMENT" if options[:auto_increment]?
      end
    end
  end

  macro after_load_hook

  end
end

require "./sqlite3/result_set"

::Jennifer::Adapter.register_adapter("sqlite3", ::Jennifer::Adapter::Sqlite3)
