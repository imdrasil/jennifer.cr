require "pg"
require "../adapter"
require "./request_methods"

alias PG_HASH = Hash(String, DB::Any | Int8 | Int16) # TODO: check if we need this

module Jennifer
  alias DBAny = Array(PG::BoolArray) | Array(PG::CharArray) | Array(PG::Float32Array) | Array(PG::Float64Array) |
                Array(PG::Int16Array) | Array(PG::Int32Array) | Array(PG::Int64Array) | Array(PG::StringArray) |
                Bool | Char | Float32 | Float64 | Int16 | Int32 | Int64 | JSON::Any | PG::Geo::Box |
                PG::Geo::Circle | PG::Geo::Line | PG::Geo::LineSegment | PG::Geo::Path | PG::Geo::Point |
                PG::Geo::Polygon | PG::Numeric | Slice(UInt8) | String | Time | UInt32 | Nil

  module Adapter
    class Postgres < Base
      include RequestMethods

      TYPE_TRANSLATIONS = {
        :integer    => "int",
        :string     => "varchar",
        :char       => "char",
        :bool       => "boolean",
        :text       => "text",
        :float      => "real",
        :double     => "double precision",
        :short      => "SMALLINT",
        :time_stamp => "timestamp",
        :date_time  => "datetime",
        :blob       => "blob",
        :var_string => "varchar",
        :json       => "json",
      }

      DEFAULT_SIZES = {
        :string     => 254,
        :var_string => 254,
      }

      def translate_type(name)
        TYPE_TRANSLATIONS[name]
      rescue e : KeyError
        raise BaseException.new("Unknown data alias #{name}")
      end

      def default_type_size(name)
        DEFAULT_SIZES[name]?
      end

      def parse_query(query, args)
        arr = [] of String
        i = 0
        args.each do
          i += 1
          arr << "$#{i}"
        end
        query % arr
      end

      def parse_query(q)
        q
      end

      def table_exist?(table)
        scalar "
          SELECT EXISTS (
            SELECT 1
            FROM   information_schema.tables
            WHERE  table_name = '#{table}'
          )"
      end

      def column_exists?(table, name)
        scalar "SELECT EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_name='#{table}' and column_name='#{name}'
        )"
      end

      def index_exists?(table, name)
        scalar "SELECT EXISTS (
          SELECT 1
          FROM   pg_class c
          JOIN   pg_namespace n ON n.oid = c.relnamespace
          WHERE  c.relname = #{name}
          AND    n.nspname = #{Config.schema}
        )"
      end

      # =========== overrides

      def add_index(table, name, options)
        if options[:type]? && ![:uniq, :unique].includes?(options[:type])
          raise ArgumentError.new("Unknown index type: #{options[:type]}")
        end
        super
      end

      def change_column(table, old_name, new_name, opts)
        column_name_part = " ALTER COLUMN #{old_name} "
        query = String.build do |s|
          s << "ALTER TABLE " << table
          if opts[:type]?
            s << column_name_part << " TYPE "
            column_type_definition(opts, s)
            s << ","
          end
          if opts[:null]?
            s << column_name_part
            if opts[:null]
              s << " DROP NOT NULL"
            else
              s << " SET NOT NULL"
            end
            s << ","
          end
          if opts[:default]?
            s << column_name_part
            if opts[:default].is_a?(Symbol) && opts[:default].as(Symbol) == :drop
              s << "DROP DEFAULT "
            else
              s << "SET DEFAULT " << self.class.t(opts[:default])
            end
            s << ","
          end
          if old_name.to_s != new_name.to_s
            s << " RENAME COLUMN " << old_name << " TO " << new_name
            s << ","
          end
        end

        exec query[0...-1]
      end

      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        query = String.build do |s|
          s << "INSERT INTO " << obj.class.table_name << "("
          opts[:fields].join(", ", s)
          s << ") values (" << self.class.escape_string(opts[:fields].size) << ")"
        end
        id = -1i64
        affected = 0i64
        transaction do
          affected = exec(parse_query(query, opts[:args]), opts[:args]).rows_affected
          if affected > 0
            id = scalar("SELECT currval(pg_get_serial_sequence('#{obj.class.table_name}', '#{obj.class.primary_field_name}'))").as(Int64)
          end
        end
        ExecResult.new(id, affected)
      end

      def exists?(query)
        args = query.select_args
        body = String.build do |s|
          s << "SELECT EXISTS(SELECT 1 "
          query.from_clause(s)
          s << parse_query(query.body_section, args) << ")"
        end
        scalar(body, args)
      end

      private def column_definition(name, options, io)
        io << name
        column_type_definition(options, io)
        if options.key?(:null)
          if options[:null]
            io << " NULL"
          else
            io << " NOT NULL"
          end
        end
        io << " PRIMARY KEY" if options[:primary]?
        io << " DEFAULT #{self.class.t(options[:default])}" if options[:default]?
      end

      private def column_type_definition(options, io)
        type = options[:serial]? || options[:auto_increment]? ? "serial" : options[:sql_type]? || translate_type(options[:type].as(Symbol))
        size = options[:size]? || default_type_size(options[:type])
        io << " " << type
        io << "(#{size})" if size
      end

      def self.create_database
        Process.run("createdb", [Config.db, "-O", Config.user, "-h", Config.host, "-U", Config.user, "-W"]).inspect
      end

      def self.drop_database
        Process.run("dropdb", [Config.db, "-h", Config.host, "-U", Config.user, "-W"]).inspect
      end
    end
  end

  macro after_load_hook
    require "./jennifer/adapter/postgres/operator"
  end
end

require "./postgres/result_set"
require "./postgres/field"
require "./postgres/exec_result"

::Jennifer::Adapter.register_adapter("postgres", ::Jennifer::Adapter::Postgres)
