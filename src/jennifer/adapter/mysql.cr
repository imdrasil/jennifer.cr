require "mysql"
require "./base"
require "./request_methods"
require "./mysql/sql_notation"

module Jennifer
  alias DBAny = DB::Any | Int16 | Int8 | JSON::Any

  module Adapter
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

      :string     => "varchar",
      :text       => "text",
      :var_string => "varstring",

      :timestamp => "datetime", # "timestamp",
      :date_time => "datetime",

      :blob => "blob",
      :json => "json",

    }

    DEFAULT_SIZES = {
      :string => 254,
    }

    class Mysql < Base
      include RequestMethods

      def translate_type(name : Symbol)
        Adapter::TYPE_TRANSLATIONS[name]
      rescue e : KeyError
        raise BaseException.new("Unknown data alias #{name}")
      end

      def default_type_size(name)
        Adapter::DEFAULT_SIZES[name]?
      end

      def table_column_count(table)
        Query["information_schema.COLUMNS"].where do
          (_table_name == table) & (_table_schema == Config.db)
        end.count
      end

      def table_exists?(table)
        Query["information_schema.TABLES"]
          .where { (_table_schema == Config.db) & (_table_name == table) }
          .exists?
      end

      def index_exists?(table, name)
        Query["information_schema.statistics"].where do
          (_table_name == table) &
            (_index_name == name) &
            (_table_schema == Config.db)
        end.exists?
      end

      def column_exists?(table, name)
        Query["information_schema.COLUMNS"].where do
          (_table_name == table) &
            (_column_name == name) &
            (_table_schema == Config.db)
        end.exists?
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
