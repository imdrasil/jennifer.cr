require "pg"
require "../adapter"
require "./request_methods"

alias PG_HASH = Hash(String, DB::Any | Int8 | Int16) # TODO: check if we need this

module Jennifer
  alias PGAny = Array(PG::BoolArray) | Array(PG::CharArray) | Array(PG::Float32Array) | Array(PG::Float64Array) |
                Array(PG::Int16Array) | Array(PG::Int32Array) | Array(PG::Int64Array) | Array(PG::StringArray) |
                Bool | Char | Float32 | Float64 | Int16 | Int32 | Int64 | JSON::Any | PG::Geo::Box |
                PG::Geo::Circle | PG::Geo::Line | PG::Geo::LineSegment | PG::Geo::Path | PG::Geo::Point |
                PG::Geo::Polygon | PG::Numeric | Slice(UInt8) | String | Time | UInt32 | Nil

  module Adapter
    class Postgres < Base
      include RequestMethods

      TYPE_TRANSLATIONS = {
        :int    => "int",
        :string => "varchar",
        :bool   => "bool",
        :text   => "text",
      }

      def type_translations
        TYPE_TRANSLATIONS
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

      # =========== overrides

      def insert(obj : Model::Base)
        opts = self.class.extract_arguments(obj.attributes_hash)
        query = "INSERT INTO #{obj.class.table_name}(#{opts[:fields].join(", ")}) values (#{self.class.escape_string(opts[:fields].size)})"
        id = -1i64
        res = nil
        transaction do
          exec parse_query(query, opts[:args]), opts[:args]
          id = scalar("SELECT currval(pg_get_serial_sequence('#{obj.class.table_name}', '#{obj.class.primary_field_name}'))").as(Int64)
        end
        ExecResult.new(id)
      end

      def exists?(query)
        args = query.select_args
        body = String.build do |s|
          s << "SELECT EXISTS(SELECT 1 "
          query.from_clause(s)
          s << parse_query(query.body_section, args) << ")"
        end
        scalar(body, args)
      rescue e
        puts body
        raise e
      end

      def self.extract_arguments(hash)
        args = [] of DB::Any
        fields = [] of String
        hash.each do |key, value|
          fields << key.to_s
          args << value
        end
        {args: args, fields: fields}
      end

      # converts single ResultSet to hash
      def result_to_hash(rs)
        h = {} of String => PGAny
        rs.column_count.times do |col|
          col_name = rs.column_name(col)
          h[col_name] = rs.read.as(PGAny)
          if h[col_name].is_a?(Int8)
            h[col_name] = (h[col_name] == 1i8).as(Bool)
          end
        end
        h
      end

      # converts single ResultSet which contains several tables
      def table_row_hash(rs)
        h = {} of String => Hash(String, PGAny)
        rs.columns.each do |col|
          h[col.table] ||= {} of String => PGAny
          h[col.table][col.name] = rs.read
          if h[col.table][col.name].is_a?(Int8)
            h[col.table][col.name] = h[col.table][col.name] == 1i8
          end
        end
        h
      end

      def result_to_array(rs)
        a = [] of PGAny
        rs.columns.each do |col|
          temp = rs.read
          if temp.is_a?(Int8)
            temp = (temp == 1i8).as(Bool)
          end
          a << temp
        end
        a
      end

      def update(q, options : Hash)
        esc = self.class.escape_string(1)
        str = "UPDATE #{q.table} SET #{options.map { |k, v| k.to_s + "= #{esc}" }.join(", ")}\n"
        args = [] of PGAny
        options.each do |k, v|
          args << v
        end
        str += q.body_section
        args += q.select_args
        exec(parse_query(str, args), args)
      end

      def distinct(query : QueryBuilder::Query, column, table)
        str = String.build do |s|
          s << "SELECT DISTINCT " << table << "." << column << "\n"
          query.from_clause(s)
          s << query.body_section
        end
        args = query.select_args
        result = [] of PGAny
        query(parse_query(str, args), args) do |rs|
          rs.each do
            result << result_to_array(rs)[0]
          end
        end
        result
      end

      def pluck(query, fields)
        result = [] of Hash(String, PGAny)
        body = query.select_query(fields)
        args = query.select_args
        query(parse_query(body, args), args) do |rs|
          rs.each do
            result << result_to_hash(rs)
          end
        end
        result
      end

      def create_table(builder : Migration::TableBuilder::CreateTable)
        buffer = "CREATE TABLE #{builder.name.to_s} ("
        builder.fields.each do |name, options|
          type = options[:serial]? || options[:auto_increment]? ? "serial" : options[:sql_type]? || type_translations[options[:type]]
          suffix = ""
          suffix += "(#{options[:size]})" if options[:size]?
          suffix += " NOT NULL" if options[:null]?
          suffix += " PRIMARY KEY" if options[:primary]?
          suffix += " DEFAULT #{self.class.t(options[:default])}" if options[:default]?
          buffer += "#{name.to_s} #{type}#{suffix},"
        end
        exec buffer[0...-1] + ")"
      end

      def self.create_database
        Process.run("createdb", [Config.db, "-O", Config.user, "-h", Config.host, "-U", Config.user, "-W"]).inspect
      end

      def self.drop_database
        Process.run("dropdb", [Config.db, "-h", Config.host, "-U", Config.user, "-W"]).inspect
      end
    end
  end

  module Model
    abstract class Base
      def initialize
        initialize({} of Symbol => PGAny)
      end
    end
  end
end

require "./postgres/result_set"
require "./postgres/field"
require "./postgres/exec_result"

::Jennifer::Adapter.register_adapter("postgres", ::Jennifer::Adapter::Postgres)
