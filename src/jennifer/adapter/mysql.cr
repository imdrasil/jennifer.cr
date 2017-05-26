require "mysql"
require "./base"
require "./request_methods"

module Jennifer
  alias DBAny = DB::Any | Int16 | Int8 | JSON::Any

  module Adapter
    alias EnumType = String

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
        :enum       => "enum",
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

      def table_exists?(table)
        v = scalar <<-SQL
          SELECT COUNT(*)
          FROM information_schema.TABLES
          WHERE TABLE_SCHEMA = '#{Config.db}' 
          AND TABLE_NAME = '#{table}'
        SQL
        v == 1
      end

      def index_exists?(table, name)
        v = scalar <<-SQL
          SELECT COUNT(*)
          from information_schema.statistics
          WHERE  table_name = '#{table}' 
          AND index_name = '#{name}'
          AND TABLE_SCHEMA = '#{Config.db}'
        SQL
        v == 1
      end

      def column_exists?(table, name)
        v = scalar <<-SQL
          SELECT COUNT(*)
          FROM information_schema.COLUMNS
          WHERE TABLE_NAME = '#{table}'
          AND COLUMN_NAME = '#{name}'
          AND TABLE_SCHEMA = '#{Config.db}'
        SQL
        v == 1
      end

      def table_row_hash(rs)
        h = {} of String => Hash(String, DBAny)
        rs.columns.each do |col|
          h[col.table] ||= {} of String => DBAny
          h[col.table][col.name] = rs.read
          if h[col.table][col.name].is_a?(Int8)
            h[col.table][col.name] = h[col.table][col.name] == 1i8
          end
        end
        h
      end

      def self.generate_schema
        io = IO::Memory.new
        error = IO::Memory.new
        s = Process.run("mysqldump \"${@}\"", ["-u", Config.user, "--no-data", "-h", Config.host, "--skip-lock-tables", Config.db], shell: true, output: io, error: error)
        raise error.to_s if s.exit_code != 0
        File.write(Config.structure_path, io.to_s)
      end

      def self.load_schema
        io = IO::Memory.new
        s = if !Config.password.empty?
              Process.run("mysql \"${@}\"", ["-u", Config.user, "-h", Config.host, "-p", Config.password, Config.db], shell: true, output: io, error: io)
            else
              Process.run("mysql \"${@}\"", ["-u", Config.user, "-h", Config.host, Config.db, "-B", "-s", "-e", "source #{Config.structure_path};"], shell: true, output: io, error: io)
            end
        raise io.to_s if s.exit_code != 0
      end
    end
  end

  macro after_load_hook
  end
end

require "./mysql/result_set"
require "./mysql/type"

::Jennifer::Adapter.register_adapter("mysql", ::Jennifer::Adapter::Mysql)
