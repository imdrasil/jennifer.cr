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
        Query["information_schema.COLUMNS"].where do
          (_table_name == table) & (_table_schema == config.db)
        end.count
      end

      def table_exists?(table)
        Query["information_schema.TABLES"]
          .where { (_table_schema == config.db) & (_table_name == table) }
          .exists?
      end

      def index_exists?(table, name)
        Query["information_schema.statistics"].where do
          (_table_name == table) &
            (_index_name == name) &
            (_table_schema == config.db)
        end.exists?
      end

      def column_exists?(table, name)
        Query["information_schema.COLUMNS"].where do
          (_table_name == table) &
            (_column_name == name) &
            (_table_schema == config.db)
        end.exists?
      end

      def view_exists?(name)
        scalar "SELECT COUNT(*) FROM (SHOW FULL TABLES IN #{name} WHERE TABLE_TYPE LIKE '%VIEW%'"
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

      def with_table_lock(table : String, type : String = "default", &block)
        transaction do |t|
          config.logger.debug("MySQL doesn't support manual locking table from prepared statement." \
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
        s = Process.run("mysqldump \"${@}\"", ["-u", config.user, "--no-data", "-h", config.host, "--skip-lock-tables", config.db], shell: true, output: io, error: error)
        raise error.to_s if s.exit_code != 0
        File.write(config.structure_path, io.to_s)
      end

      def self.load_schema
        io = IO::Memory.new
        s = if !config.password.empty?
              Process.run("mysql \"${@}\"", ["-u", config.user, "-h", config.host, "-p", config.password, config.db], shell: true, output: io, error: io)
            else
              Process.run("mysql \"${@}\"", ["-u", config.user, "-h", config.host, config.db, "-B", "-s", "-e", "source #{config.structure_path};"], shell: true, output: io, error: io)
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
