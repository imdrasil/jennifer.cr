require "../base_sql_generator"

module Jennifer
  module Mysql
    class SQLGenerator < Adapter::BaseSQLGenerator
      def self.insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        String.build do |s|
          s << "INSERT INTO " << quote_identifier(obj.class.table_name)
          if opts[:fields].empty?
            s << " VALUES ()"
          else
            s << "("
            quote_identifiers(opts[:fields]).join(s, ", ")
            s << ") VALUES (" << escape_string(opts[:fields].size) << ") "
          end
        end
      end

      # Generates update request depending on given query and hash options. Allows
      # joins inside of query.
      def self.update(query, options : Hash)
        esc = escape_string(1)
        String.build do |s|
          s << "UPDATE " << quote_identifier(query.table)
          s << ' '
          _joins = query._joins?

          unless _joins.nil?
            where_clause(s, _joins[0].on)
            _joins[1..-1].join(s, " ") { |e| s << e.as_sql(self) }
          end
          s << " SET "
          options.join(s, ", ") { |(k, _)| s << quote_identifier(k) << " = " << esc }
          s << " "
          where_clause(s, query.tree)
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
