require "../base_sql_generator"

module Jennifer
  module Postgres
    class SQLGenerator < Adapter::BaseSQLGenerator
      def self.insert(obj : Model::Base, with_primary_field = true)
        opts = obj.arguments_to_insert
        String.build do |s|
          s << "INSERT INTO " << obj.class.table_name
          unless opts[:fields].empty?
            s << "("
            opts[:fields].join(", ", s)
            s << ") VALUES (" << escape_string(opts[:fields].size) << ") "
          else
            s << " DEFAULT VALUES"
          end

          if with_primary_field
            s << " RETURNING " << obj.class.primary_field_name
          end
        end
      end

      # Generates update request depending on given query and hash options. Allows
      # joins inside of query.
      def self.update(query, options : Hash)
        esc = escape_string(1)
        String.build do |s|
          s << "UPDATE " << query._table << " SET "
          options.map { |k, v| "#{k.to_s}= #{esc}" }.join(", ", s)
          s << ' '

          from_clause(s, query, query._joins![0].table_name(self)) if query._joins
          where_clause(s, query.tree)
          if query._joins
            where_clause(s, query._joins![0].on)
            query._joins![1..-1].join(" ", s) { |e| s << e.as_sql(self) }
          end
        end
      end

      # =================== utils

      def self.operator_to_sql(operator)
        case operator
        when :like
          "LIKE"
        when :not_like
          "NOT LIKE"
        when :regexp
          "~"
        when :not_regexp
          "!~"
        when :==
          "="
        when :is
          "IS"
        when :is_not
          "IS NOT"
        when :contain
          "@>"
        when :contained
          "<@"
        when :overlap
          "&&"
        else
          operator.to_s
        end
      end

      def self.json_path(path : QueryBuilder::JSONSelector)
        operator =
          case path.type
          when :path
            "#>"
          when :take
            "->"
          else
            raise "Wrong json path type"
          end
        "#{path.identifier}#{operator}#{quote(path.path)}"
      end

      # for postgres column name
      def self.escape(value : String)
        case value
        when "NULL", "TRUE", "FALSE"
          value
        else
          value = value.gsub(/\\/, ARRAY_ESCAPE).gsub(/"/, "\\\"")
          "\"#{value}\""
        end
      end

      def self.escape(value : Nil)
        quote(value)
      end

      def self.escape(value : Bool)
        quote(value)
      end

      def self.escape(value : Int32 | Int16 | Float64 | Float32)
        quote(value)
      end

      def self.quote(value : String)
        "'#{value.gsub(/\\/, "\&\&").gsub(/'/, "''")}'"
      end

      def self.parse_query(query, args : Array(DBAny))
        arr = Array(String).new(args.size)
        args.each_with_index do |arg, i|
          args[i] = arg.as(Time).to_utc if arg.is_a?(Time)
          arr << "$#{i + 1}"
        end
        {query % arr, args}
      end
    end
  end
end
