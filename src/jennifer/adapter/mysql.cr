require "mysql"
require "./base"
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
      :varchar    => "varchar",
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

    # NOTE: now is not used
    TABLE_LOCK_TYPES = {
      "r"       => "READ",
      "rl"      => "READ LOCAL",
      "w"       => "WRITE",
      "lpw"     => "LOW_PRIORITY WRITE",
      "default" => "READ", # "r"
    }

    class Mysql < Base
      def translate_type(name : Symbol)
        Adapter::TYPE_TRANSLATIONS[name]
      rescue e : KeyError
        raise BaseException.new("Unknown data alias #{name}")
      end

      def default_type_size(name)
        Adapter::DEFAULT_SIZES[name]?
      end

      def table_column_count(table)
        if table_exists?(table)
          Query["information_schema.COLUMNS"].where do
            (_table_name == table) & (_table_schema == Config.db)
          end.count
        else
          -1
        end
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

      def view_exists?(name)
        Query["information_schema.TABLES"]
          .where { (_table_schema == Config.db) & (_table_type == "VIEW") & (_table_name == name) }
          .exists?
      end

      def with_table_lock(table : String, type : String = "default", &block)
        transaction do |t|
          Config.logger.debug("MySQL doesn't support manual locking table from prepared statement." \
                              " Instead of this only transaction was started.")
          yield t
        end
        # transaction do |t|
        #   exec "LOCK TABLES #{table} #{TABLE_LOCK_TYPES[type]}"
        #   yield t
        #   exec "UNLOCK TABLES"
        # end
        # rescue e : KeyError
        # raise BaseException.new("MySQL don't support table lock type '#{type}'.")
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
