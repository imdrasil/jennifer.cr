require "pg"
require "./base"

require "./postgres/result_set"
require "./postgres/exec_result"

require "./postgres/sql_generator"
require "./postgres/schema_processor"

require "./postgres/command_interface"

module Jennifer
  module Postgres
    class Adapter < Adapter::Base
      alias EnumType = Bytes

      TYPE_TRANSLATIONS = {
        :integer => "int",      # Int32
        :short   => "SMALLINT", # Int16
        :bigint  => "BIGINT",   # Int64
        :oid     => "oid",      # UInt32

        :float  => "real",             # Float32
        :double => "double precision", # Float64

        :numeric => "numeric", # PG::Numeric
        :decimal => "decimal", # PG::Numeric - alias for numeric

        :string     => "varchar",
        :char       => "char",
        :bool       => "boolean",
        :text       => "text",
        :var_string => "varchar",
        :varchar    => "varchar",
        :blchar     => "blchar", # String

        :uuid => "uuid", # String

        :timestamp   => "timestamp",
        :timestamptz => "timestamptz", # Time
        :date_time   => "datetime",

        :blob  => "blob",
        :bytea => "bytea",

        :json  => "json",  # JSON
        :jsonb => "jsonb", # JSON
        :xml   => "xml",   # String

        :point   => "point",
        :lseg    => "lseg",
        :path    => "path",
        :box     => "box",
        :polygon => "polygon",
        :line    => "line",
        :circle  => "circle",
      }

      DEFAULT_SIZES = {
        :string     => 254,
        :var_string => 254,
      }

      TABLE_LOCK_TYPES = {
        "as"      => "ACCESS SHARE",
        "rs"      => "ROW SHARE",
        "re"      => "ROW EXCLUSIVE",
        "sue"     => "SHARE UPDATE EXCLUSIVE",
        "s"       => "SHARE",
        "sre"     => "SHARE ROW EXCLUSIVE",
        "e"       => "EXCLUSIVE",
        "ae"      => "ACCESS EXCLUSIVE",
        "default" => "SHARE", # "s"
      }

      def sql_generator
        SQLGenerator
      end

      def self.command_interface
        @@command_interface ||= CommandInterface.new(Config.instance)
      end

      def schema_processor
        @schema_processor ||= SchemaProcessor.new(self)
      end

      def prepare
        _query = <<-SQL
          SELECT e.enumtypid
          FROM pg_type t, pg_enum e
          WHERE t.oid = e.enumtypid
        SQL

        query(_query) do |rs|
          rs.each do
            PG::Decoders.register_decoder PG::Decoders::StringDecoder.new, rs.read(UInt32).to_i
          end
        end
        super
      end

      def translate_type(name)
        TYPE_TRANSLATIONS[name]
      rescue e : KeyError
        raise BaseException.new("Unknown data alias #{name}")
      end

      def default_type_size(name)
        DEFAULT_SIZES[name]?
      end

      def refresh_materialized_view(name)
        exec "REFRESH MATERIALIZED VIEW #{name}"
      end

      def table_column_count(table)
        if table_exists?(table)
          Query["information_schema.columns"].where { _table_name == table }.count
        elsif material_view_exists?(table)
          # materialized view
          Query["pg_attribute"]
            .join("pg_class") { _pg_attribute__attrelid == _oid }
            .join("pg_namespace") { _oid == _pg_class__relnamespace }
            .where do
            (_attnum > 0) &
              (_pg_namespace__nspname == Config.schema) &
              (_pg_class__relname == table) &
              _attisdropped.not
          end.count
        else
          -1
        end
      end

      def material_view_exists?(name)
        Query["pg_class"].join("pg_namespace") { _oid == _pg_class__relnamespace }.where do
          (_relkind == "m") &
            (_pg_namespace__nspname == Config.schema) &
            (_relname == name)
        end.exists?
      end

      # Returns if table exists.
      def table_exists?(table)
        Query["information_schema.tables"]
          .where { _table_name == table }
          .exists?
      end

      def column_exists?(table, name)
        Query["information_schema.columns"]
          .where { (_table_name == table) & (_column_name == name) }
          .exists?
      end

      def index_exists?(table, name)
        Query["pg_class"]
          .join("pg_namespace") { _oid == _pg_class__relnamespace }
          .where { (_pg_class__relname == name) & (_pg_namespace__nspname == Config.schema) }
          .exists?
      end

      def view_exists?(name)
        Query["information_schema.views"]
          .where { (_table_schema == Config.schema) & (_table_name == name) }
          .exists?
      end

      def data_type_exists?(name)
        Query["pg_type"].where { _typname == name }.exists?
      end

      def enum_values(name)
        query_array("SELECT unnest(enum_range(NULL::#{name})::varchar[])", String).map { |array| array[0] }
      end

      def with_table_lock(table : String, type : String = "default", &block)
        transaction do |t|
          exec "LOCK TABLE #{table} IN #{TABLE_LOCK_TYPES[type]} MODE"
          yield t
        end
      rescue e : KeyError
        raise BaseException.new("Unknown table lock type '#{type}'.")
      end

      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        query_opts = parse_query(sql_generator.insert(obj, obj.class.primary_auto_incrementable?), opts[:args])
        id = -1i64
        affected = 0i64
        if obj.class.primary_auto_incrementable?
          id = scalar(*query_opts).as(Int).to_i64
          affected += 1 if id > 0
        else
          affected = exec(*query_opts).rows_affected
        end

        ExecResult.new(id, affected)
      end

      def self.bulk_insert(collection : Array(Model::Base))
        opts = collection.flat_map(&.arguments_to_insert[:args])
        # TODO: unify parse_query
        query_opts = parse_query(sql_generator.bulk_insert(collection))
        # TODO: change to checking for autoincrementability
        affected = exec(qyery, opts).rows_affected
        if affected != collection.size
          raise ::Jennifer::BaseException.new("Bulk insert failed with #{collection.size - affected} records.")
        end
      end

      def exists?(query)
        scalar(*sql_generator.exists(query))
      end
    end
  end
end

require "./postgres/converters"
require "./postgres/criteria"
require "./postgres/numeric"
require "./postgres/migration/table_builder/base"
require "./postgres/migration/table_builder/*"

::Jennifer::Adapter.register_adapter("postgres", ::Jennifer::Postgres::Adapter)
