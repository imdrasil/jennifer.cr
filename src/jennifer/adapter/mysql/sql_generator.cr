require "../base_sql_generator"

module Jennifer
  module Mysql
    class SQLGenerator < Adapter::BaseSQLGenerator
      def self.insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        String.build do |io|
          io << "INSERT INTO " << quote_identifier(obj.class.table_name)
          if opts[:fields].empty?
            io << " VALUES ()"
          else
            io << "("
            quote_identifiers(opts[:fields]).join(io, ", ")
            io << ") VALUES (" << escape_string(opts[:fields].size) << ") "
          end
        end
      end

      # Generates update request depending on given query and hash options. Allows
      # joins inside of query.
      def self.update(query, options : Hash)
        esc = escape_string(1)
        String.build do |io|
          io << "UPDATE " << quote_identifier(query.table)
          io << ' '
          _joins = query._joins?

          unless _joins.nil?
            where_clause(io, _joins[0].on)
            _joins[1..-1].join(io, " ") { |e| io << e.as_sql(self) }
          end
          io << " SET "
          options.join(io, ", ") { |(k, _)| io << quote_identifier(k) << " = " << esc }
          io << " "
          where_clause(io, query.tree)
        end
      end

      def self.insert_on_duplicate(table, fields, rows : Int32, unique_fields, on_conflict)
        is_ignore = on_conflict.empty?
        String.build do |io|
          io << "INSERT "
          io << "IGNORE " if is_ignore
          io << "INTO " << quote_identifier(table) << " ("
          quote_identifiers(fields).join(io, ", ")
          escaped_row = "(" + escape_string(fields.size) + ")"
          io << ") VALUES "
          rows.times.join(io, ", ") { io << escaped_row }
          unless is_ignore
            io << " ON DUPLICATE KEY UPDATE "
            on_conflict.each_with_index do |(field, value), index|
              io << ", " if index != 0
              io << field_assign_statement(field.to_s, value)
            end
          end
        end
      end

      def self.json_path(path : QueryBuilder::JSONSelector)
        value = path.path.is_a?(Number) ? "$[#{path.path}]" : path.path
        "#{path.identifier(self)}->#{json_quote(value)}"
      end

      def self.order_expression(expression : QueryBuilder::OrderExpression)
        if expression.null_position.none?
          super
        else
          String.build do |io|
            io << "CASE WHEN " <<
              expression.criteria.is(nil).as_sql(self) <<
              " THEN 0 ELSE 1 " <<
              (expression.null_position.last? ? "DESC" : "ASC") <<
              " END, " <<
              super
          end
        end
      end

      def self.values_expression(field)
        "VALUES(#{field})"
      end

      def self.json_quote(value : String)
        "\"#{value.gsub(Jennifer::Adapter::Quoting::STRING_QUOTING_PATTERNS)}\""
      end

      def self.json_quote(value)
        quote(value)
      end

      def self.quote_json_string(value : String)
        if value =~ /[\\"]/
          raise ArgumentError.new("Mysql adapter doesn't support quoting '\\' or '\"' symbols in JSON strings")
        end

        super
      end

      def self.quote(value : String)
        "'" + value.gsub(Jennifer::Adapter::Quoting::STRING_QUOTING_PATTERNS) + "'"
      end

      def self.quote_identifier(identifier : String | Symbol)
        %(`#{identifier.to_s.gsub('`', "``")}`)
      end

      def self.quote_table(table : String)
        %(`#{table.gsub(".", "`.`")}`)
      end
    end
  end
end
