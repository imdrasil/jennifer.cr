require "./json_encoder"
require "./quoting"

module Jennifer
  module Adapter
    abstract class BaseSQLGenerator
      module ClassMethods
        # Generates query for inserting new record to db
        abstract def insert(obj : Model::Base)
        abstract def json_path(path : QueryBuilder::JSONSelector)
        abstract def insert_on_duplicate(table, fields, rows : Int32, unique_fields, on_conflict)

        # Generates SQL for VALUES reference in `INSERT ... ON DUPLICATE` query.
        abstract def values_expression(field : Symbol)
      end

      extend ClassMethods
      extend Quoting

      def self.explain(query)
        "EXPLAIN #{self.select(query)}"
      end

      # Generates insert query
      def self.insert(table, hash)
        String.build do |io|
          io << "INSERT INTO " << quote_identifier(table) << "("
          quote_identifiers(hash.keys).join(io, ", ")
          io << ") VALUES (" << escape_string(hash.size) << ")"
        end
      end

      def self.bulk_insert(table : String, field_names : Array(String), rows : Int32)
        String.build do |io|
          io << "INSERT INTO " << quote_identifier(table) << "("
          quote_identifiers(field_names).join(io, ", ") { |e| io << e }
          io << ") VALUES "
          escaped_row = "(" + escape_string(field_names.size) + ")"
          rows.times.join(io, ", ") { io << escaped_row }
        end
      end

      def self.bulk_insert(table : String, field_names : Array(String), rows : Array)
        String.build do |io|
          io << "INSERT INTO " << quote_identifier(table) << "("
          quote_identifiers(field_names).join(io, ", ") { |e| io << e }
          io << ") VALUES "

          rows.each_with_index do |row, index|
            io << ',' if index != 0
            io << '('
            row.each_with_index do |col, col_index|
              io << ',' if col_index != 0
              io << quote(col)
            end
            io << ')'
          end
        end
      end

      # Generates common select SQL request
      def self.select(query, exact_fields : Array = [] of String)
        String.build do |io|
          with_clause(io, query)
          select_clause(io, query, exact_fields)
          from_clause(io, query)
          body_section(io, query)
        end
      end

      def self.truncate(table : String)
        "TRUNCATE #{quote_identifier(table)}"
      end

      def self.delete(query)
        String.build do |io|
          io << "DELETE "
          from_clause(io, query)
          body_section(io, query)
        end
      end

      def self.exists(query)
        String.build do |io|
          with_clause(io, query)
          io << "SELECT EXISTS(SELECT 1 "
          from_clause(io, query)
          body_section(io, query)
          io << ")"
        end
      end

      def self.count(query)
        String.build do |io|
          with_clause(io, query)
          io << "SELECT COUNT(*) "
          from_clause(io, query)
          body_section(io, query)
        end
      end

      def self.update(obj : Model::Base)
        esc = escape_string(1)
        String.build do |io|
          io << "UPDATE " << quote_identifier(obj.class.table_name) << " SET "
          obj.arguments_to_save[:fields].map { |field| "#{quote_identifier(field)}= #{esc}" }.join(io, ", ")
          io << " WHERE " << quote_identifier(obj.class.primary_field_name) << " = " << esc
        end
      end

      def self.update(query, options : Hash)
        esc = escape_string(1)
        String.build do |io|
          io << "UPDATE " << quote_table(query.table) << " SET "
          options.map { |k, _| "#{quote_identifier(k)}= #{esc}" }.join(io, ", ")
          io << ' '
          body_section(io, query)
        end
      end

      def self.modify(q, modifications : Hash)
        String.build do |io|
          io << "UPDATE " << quote_table(q.table) << " SET "
          modifications.each_with_index do |(field, value), i|
            io << ", " if i != 0
            io << field_assign_statement(field.to_s, value)
          end
          io << ' '
          body_section(io, q)
        end
      end

      # ========== SQL clauses ================

      def self.body_section(io : String::Builder, query)
        join_clause(io, query)
        where_clause(io, query)
        group_clause(io, query)
        order_clause(io, query)
        limit_clause(io, query)
        having_clause(io, query)
        lock_clause(io, query)
        union_clause(io, query)
      end

      def self.union_clause(io : String::Builder, query)
        return unless query._unions?

        query._unions!.each do |union_tuple|
          io << " UNION "
          io << "ALL " if union_tuple[:all]
          io << self.select(union_tuple[:query])
        end
      end

      def self.lock_clause(io : String::Builder, query)
        return if query._lock.nil?

        io << ' '
        io << (query._lock.is_a?(String) ? query._lock : "FOR UPDATE")
        io << ' '
      end

      # Generates `SELECT` query clause.
      def self.select_clause(io : String::Builder, query, exact_fields : Array = [] of String)
        io << "SELECT "
        io << "DISTINCT " if query._distinct
        if query._raw_select
          io << query._raw_select.not_nil!
        else
          table = quote_table(query.table)
          if exact_fields.empty? || !query._select_fields!.empty?
            query._select_fields.join(io, ", ") { |field| io << field.definition(self) }
          else
            exact_fields.join(io, ", ") { |field| io << "#{table}.#{quote_identifier(field)}" }
          end
        end
        io << ' '
      end

      # `FROM` clause for quoted table *from*
      def self.from_clause(io : String::Builder, from : String)
        io << "FROM " << from << ' '
      end

      # Generates `FROM` query clause.
      def self.from_clause(io : String::Builder, query)
        _from = query._from
        if _from
          io << "FROM "
          if _from.is_a?(String)
            io << _from
          else
            io << "( " <<
              if query.is_a?(QueryBuilder::ModelQuery)
                self.select(_from)
              else
                self.select(_from.as(QueryBuilder::Query))
              end
            io << " ) "
          end
        elsif !query._table.empty?
          from_clause(io, quote_table(query.table))
        end
      end

      # Generates `GROUP BY` query clause.
      def self.group_clause(io : String::Builder, query)
        return unless query._groups?

        io << "GROUP BY "
        query._groups!.each.join(io, ", ") { |criterion| io << criterion.as_sql(self) }
        io << ' '
      end

      # Generates `HAVING` query clause.
      def self.having_clause(io : String::Builder, query)
        return unless query._having

        io << "HAVING " << query._having.not_nil!.as_sql(self) << ' '
      end

      # Generates `JOIN` query clause.
      def self.join_clause(io : String::Builder, query)
        return unless query._joins?

        query._joins!.join(io, " ") { |j| io << j.as_sql(self) }
      end

      # Generates `WHERE` query clause.
      def self.where_clause(io : String::Builder, query : QueryBuilder::Query | QueryBuilder::ModelQuery)
        where_clause(io, query.tree.not_nil!) if query.tree
      end

      # :ditto:
      def self.where_clause(io : String::Builder, tree)
        return unless tree

        io << "WHERE " << tree.not_nil!.as_sql(self) << ' '
      end

      # Generates `LIMIT` clause.
      def self.limit_clause(io : String::Builder, query)
        io.print "LIMIT ", query._limit.not_nil!, ' ' if query._limit
        io.print "OFFSET ", query._offset.not_nil!, ' ' if query._offset
      end

      # Generates `ORDER BY` clause.
      def self.order_clause(io : String::Builder, query)
        return unless query._order?

        io << "ORDER BY "
        query._order!.join(io, ", ") { |expression| io.print expression.as_sql(self) }
        io << ' '
      end

      # Generates `WITH` clause.
      def self.with_clause(io : String::Builder, query)
        return unless query._ctes?

        io << "WITH "
        if query._ctes!.any?(&.recursive?)
          io << "RECURSIVE "
        end

        query._ctes!.each_with_index do |cte, index|
          cte_query = cte.query
          io << ", " if index != 0
          io << cte.name << " AS ("
          io <<
            if cte_query.is_a?(QueryBuilder::ModelQuery)
              self.select(cte_query.as(QueryBuilder::ModelQuery))
            else
              self.select(cte_query.as(QueryBuilder::Query))
            end
          io << ") "
        end
      end

      # Returns `CAST` expression.
      def self.cast_expression(expression, type : String)
        "CAST(#{expression.as_sql(self)} AS #{type})"
      end

      # ======== utils

      def self.order_expression(expression : QueryBuilder::OrderExpression)
        "#{expression.criteria.identifier(self)} #{expression.direction}"
      end

      # Converts operator to SQL.
      def self.operator_to_sql(operator : Symbol)
        case operator
        when :like, :ilike
          "LIKE"
        when :not_like
          "NOT LIKE"
        when :regexp
          "REGEXP"
        when :not_regexp
          "NOT REGEXP"
        when :==
          "="
        when :is
          "IS"
        when :is_not
          "IS NOT"
        else
          operator.to_s
        end
      end

      def self.parse_query(query : String, args : Array(DBAny))
        if Config.time_zone_aware_attributes
          args.each_with_index do |arg, i|
            args[i] = arg.to_utc if arg.is_a?(Time) && !arg.utc?
          end
        end
        {query % Array.new(args.size, "?"), args}
      end

      private def self.field_assign_statement(field, _value : DBAny)
        "#{quote_identifier(field)} = #{escape_string(1)}"
      end

      private def self.field_assign_statement(field, value : QueryBuilder::Statement)
        "#{quote_identifier(field)} = #{value.as_sql(self)}"
      end
    end
  end
end
