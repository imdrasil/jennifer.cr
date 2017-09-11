module Jennifer
  module Adapter
    class BaseSqlGenerator
      ARRAY_ESCAPE = "\\\\\\\\"

      # Generates insert query
      def self.insert(table, hash)
        String.build do |s|
          s << "INSERT INTO " << table << "("
          hash.keys.join(", ", s)
          s << ") VALUES (" << Adapter.adapter_class.escape_string(hash.size) << ")"
        end
      end

      # Generates query for inserting new record to db
      def self.insert(obj : Model::Base)
        raise "Not implemented"
      end

      # Generates common select sql request
      def self.select(query, exact_fields = [] of String)
        String.build do |s|
          select_clause(s, query, exact_fields)
          body_section(s, query)
        end
      end

      # Generates select sql request with distinct
      def self.select_distinct(query, column, table)
        String.build do |s|
          s << "SELECT DISTINCT " << table << "." << column << "\n"
          from_clause(s, query)
          body_section(s, query)
        end
      end

      # TODO: unify method generting - #parse_query should be called here or by caller
      def self.delete(query)
        parse_query(
          String.build do |s|
            s << "DELETE "
            from_clause(s, query)
            body_section(s, query)
          end,
          query.select_args_count
        )
      end

      def self.exists(query)
        parse_query(
          String.build do |s|
            s << "SELECT EXISTS(SELECT 1 "
            from_clause(s, query)
            body_section(s, query)
            s << ")"
          end,
          query.select_args_count
        )
      end

      def self.count(query)
        parse_query(
          String.build do |s|
            s << "SELECT COUNT(*) "
            from_clause(s, query)
            body_section(s, query)
          end,
          query.select_args_count
        )
      end

      def self.update(obj : Model::Base)
        esc = escape_string(1)
        String.build do |s|
          s << "UPDATE " << obj.class.table_name << " SET "
          obj.arguments_to_save[:fields].map { |f| "#{f}= #{esc}" }.join(", ", s)
          s << " WHERE " << obj.class.primary_field_name << " = " << esc
        end
      end

      def self.update(query, options : Hash)
        esc = Adapter.adapter_class.escape_string(1)
        String.build do |s|
          s << "UPDATE " << query.table << " SET "
          options.map { |k, v| "#{k.to_s}= #{esc}" }.join(", ", s)
          s << "\n"
          body_section(s, query)
        end
      end

      def self.modify(q, modifications : Hash)
        esc = escape_string(1)
        String.build do |s|
          s << "UPDATE " << q.table << " SET "
          modifications.map { |field, value| "#{field.to_s} = #{field.to_s} #{value[:operator]} #{esc}" }.join(", ", s)
          s << "\n"
          body_section(s, q)
        end
      end

      # ========== sql clauses ================

      def self.body_section(io, query)
        join_clause(io, query)
        where_clause(io, query.tree)
        order_clause(io, query)
        limit_clause(io, query)
        group_clause(io, query)
        having_clause(io, query)
        lock_clause(io, query)
        union_clause(io, query)
      end

      def self.union_clause(io, query)
        return if query._unions.empty?
        query._unions.each do |u|
          io << " UNION " << self.select(u)
        end
      end

      def self.lock_clause(io, query)
        return if query._lock.nil?
        io << (query._lock.is_a?(Bool) ? " FOR UPDATE " : query._lock)
      end

      def self.select_clause(s, query : QueryBuilder::ModelQuery, exact_fields = [] of String)
        s << "SELECT "
        unless query._raw_select
          table = query._table
          if !exact_fields.empty?
            exact_fields.map { |f| "#{table}.#{f}" }.join(", ", s)
          else
            s << table << ".*"
            unless query._relations.empty?
              s << ", "
              query._relations.each_with_index do |r, i|
                s << ", " if i != 0
                # TODO: cover with tests
                s << (query._table_aliases[r]? || query.model_class.relations[r].table_name) << ".*"
              end
            end
          end
        else
          # NOTE: `not_nil!` is a fix for "BUG: no target defs"
          s << query._raw_select.not_nil!
        end
        s << "\n"
        from_clause(s, query)
      end

      # Renders SELECT and FROM parts
      def self.select_clause(io, query, exact_fields = [] of String)
        io << "SELECT "
        unless query._raw_select
          table = query._table
          if !exact_fields.empty?
            # TODO: avoid creating extra arrays
            exact_fields.map { |f| "#{table}.#{f}" }.join(", ", io)
          else
            io << table << ".*"
          end
        else
          io << query._raw_select
        end
        io << "\n"

        from_clause(io, query)
      end

      def self.from_clause(io, query, from = nil)
        io << "FROM "
        return io << (from || query._table) << "\n" unless query._from
        io << "( " <<
          if query._from.is_a?(String)
            query._from
          else
            if query.is_a?(QueryBuilder::ModelQuery)
              SqlGenerator.select(query._from.as(QueryBuilder::ModelQuery))
            else
              SqlGenerator.select(query._from.as(QueryBuilder::Query))
            end
          end
        io << " ) "
      end

      def self.group_clause(io, query)
        return if query._group.empty?
        # TODO: make building better
        io << "GROUP BY "
        query._group.map { |t, fields| fields.map { |f| "#{t}.#{f}" }.join(", ") }.join(", ", io)
        io << "\n"
      end

      def self.having_clause(io, query)
        return unless query._having
        io << "HAVING " << query._having.not_nil!.as_sql << "\n"
      end

      def self.join_clause(io, query)
        query._joins.map(&.as_sql).join(' ', io)
      end

      def self.where_clause(io, query : QueryBuilder::Query | QueryBuilder::ModelQuery)
        where_clause(io, query.tree)
      end

      def self.where_clause(io, tree)
        return unless tree
        io << "WHERE " << tree.not_nil!.as_sql << "\n"
      end

      def self.limit_clause(io, query)
        io.print "LIMIT ", query._limit, "\n" if query._limit
        io.print "OFFSET ", query._offset, "\n" if query._offset
      end

      def self.order_clause(io, query)
        return if query._order.empty?
        io << "ORDER BY "
        query._order.each_with_index do |(k, v), i|
          io << ", " if i > 0
          io << k << " " << v.upcase
        end
        io << "\n"
      end

      # ======== utils

      def self.operator_to_sql(operator)
        case operator
        when :like
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

      def self.json_path(path : QueryBuilder::JSONSelector)
        raise "Not Implemented"
      end

      def self.quote(value : Nil)
        "NULL"
      end

      def self.quote(value : Bool)
        value ? "TRUE" : "FALSE"
      end

      def self.quote(value : Int32 | Int16 | Float64 | Float32)
        value.to_s
      end

      def self.escape_string(size = 1)
        case size
        when 1
          "%s"
        when 2
          "%s, %s"
        when 3
          "%s, %s, %s"
        else
          size.times.map { "%s" }.join(", ")
        end
      end

      def self.parse_query(query, arg_count)
        arr = [] of String
        arg_count.times do
          arr << "?"
        end
        query % arr
      end

      def self.parse_query(query)
        query
      end
    end
  end
end
