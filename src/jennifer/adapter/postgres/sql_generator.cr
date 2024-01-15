require "../base_sql_generator"
require "./quoting"

module Jennifer
  module Postgres
    class SQLGenerator < Adapter::BaseSQLGenerator
      extend Quoting

      # :nodoc:
      OPERATORS = {
        like:       "LIKE",
        not_like:   "NOT LIKE",
        regexp:     "~",
        not_regexp: "!~",
        "==":       "=",
        is:         "IS",
        is_not:     "IS NOT",
        contain:    "@>",
        contained:  "<@",
        overlap:    "&&",
      }

      def self.insert(obj : Model::Base, with_primary_field = true)
        opts = obj.arguments_to_insert
        String.build do |io|
          io << "INSERT INTO " << quote_identifier(obj.class.table_name)
          if opts[:fields].empty?
            io << " DEFAULT VALUES"
          else
            io << "("
            quote_identifiers(opts[:fields]).join(io, ", ")
            io << ") VALUES (" << escape_string(opts[:fields].size) << ") "
          end

          if with_primary_field
            io << " RETURNING " << quote_identifier(obj.class.primary_field_name)
          end
        end
      end

      # Generates update request depending on given query and hash options.
      #
      # Allows joins inside of query.
      def self.update(query, options : Hash)
        esc = escape_string(1)
        String.build do |io|
          io << "UPDATE " << quote_identifier(query._table) << " SET "
          options.map { |k, _| "#{quote_identifier(k)}= #{esc}" }.join(io, ", ")
          io << ' '

          from_clause(io, query._joins![0].table_name(self)) if query._joins?
          where_clause(io, query.tree)
          if query._joins?
            where_clause(io, query._joins![0].on)
            query._joins![1..-1].join(io, " ") { |e| io << e.as_sql(self) }
          end
        end
      end

      def self.insert_on_duplicate(table, fields, rows : Int32, unique_fields, on_conflict)
        String.build do |io|
          io << "INSERT INTO " << quote_identifier(table) << " ("
          quote_identifiers(fields).join(io, ", ")
          escaped_row = "(" + escape_string(fields.size) + ")"
          io << ") VALUES "
          rows.times.join(io, ", ") { io << escaped_row }
          io << " ON CONFLICT "
          unless unique_fields.empty?
            io << "("
            unique_fields.join(io, ", ") { |field| io << quote_identifier(field) }
            io << ") "
          end
          if on_conflict.empty?
            io << "DO NOTHING"
          else
            io << "DO UPDATE SET "
            on_conflict.each_with_index do |(field, value), index|
              io << ", " if index != 0
              io << field_assign_statement(field.to_s, value)
            end
          end
        end
      end

      # =================== utils

      def self.values_expression(field : Symbol)
        "excluded.#{field}"
      end

      def self.order_expression(expression : QueryBuilder::OrderExpression)
        if expression.null_position.none?
          super
        else
          super + " NULLS #{expression.null_position}"
        end
      end

      def self.operator_to_sql(operator : Symbol)
        OPERATORS[operator]? || operator.to_s
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
        "#{path.identifier(self)}#{operator}#{quote(path.path)}"
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

      def self.parse_query(query, args : Array(DBAny))
        arr = Array(String).new(args.size)
        args.each_with_index do |arg, i|
          args[i] = arg.to_utc if arg.is_a?(Time)
          arg.map!(&.to_utc) if arg.is_a?(Array(Time))
          arr << "$#{i + 1}"
        end
        {query % arr, args}
      end
    end
  end
end
