module Jennifer
  module Adapter
    class BaseSqlGenerator
      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        String.build do |s|
          s << "INSERT INTO " << obj.class.table_name << "("
          opts[:fields].join(", ", s)
          s << ") values (" << Adapter.adapter_class.escape_string(opts[:fields].size) << ")"
        end
      end

      def self.select(query : QueryBuilder::Query, exact_fields = [] of String)
        String.build do |s|
          select_clause(s, query, exact_fields)
          body_section(s, query)
        end
      end

      def self.select_distinct(query : QueryBuilder::Query, column, table)
        String.build do |s|
          s << "SELECT DISTINCT " << table << "." << column << "\n"
          from_clause(s, query)
          body_section(s, query)
        end
      end

      def self.delete(query)
        String.build do |s|
          s << "DELETE "
          from_clause(s, query)
          body_section(s, query)
        end
      end

      def self.exists(query)
        String.build do |s|
          s << "SELECT EXISTS(SELECT 1 "
          from_clause(s, query)
          body_section(s, query)
          s << ")"
        end
      end

      def self.count(query)
        String.build do |s|
          s << "SELECT COUNT(*) "
          from_clause(s, query)
          body_section(s, query)
        end
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

      def self.body_section(io, query : QueryBuilder::Query)
        join_clause(io, query)
        where_clause(io, query)
        order_clause(io, query)
        limit_clause(io, query)
        group_clause(io, query)
        having_clause(io, query)
      end

      def self.select_clause(io, query : QueryBuilder::ModelQuery, exact_fields = [] of String)
        io << "SELECT "
        unless query._raw_select
          table = query._table
          if exact_fields.size > 0
            exact_fields.map { |f| "#{table}.#{f}" }.join(", ", io)
          else
            io << table << ".*"
            unless query._relations.empty?
              io << ", "
              query._relations.each_with_index do |r, i|
                io << ", " if i != 0
                # TODO: cover with tests
                io << (query._table_aliases[r]? || query.model_class.relations[r].table_name) << ".*"
              end
            end
          end
        else
          io << query._raw_select
        end
        io << "\n"
        from_clause(io, query)
      end

      # renders SELECT and FROM parts
      def self.select_clause(io, query : QueryBuilder::Query, exact_fields = [] of String)
        io << "SELECT "
        unless query._raw_select
          table = query._table
          if exact_fields.size > 0
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

      def self.from_clause(io, query : QueryBuilder::Query)
        io << "FROM "
        return io << query._table << "\n" unless query._from
        io << "( " <<
          if query._from.is_a?(String)
            query._from
          else
            SqlGenerator.select(query._from.as(QueryBuilder::Query))
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
        io << "HAVING " << query._having.not_nil!.to_sql << "\n"
      end

      def self.join_clause(io, query)
        query._joins.map(&.to_sql).join(' ', io)
      end

      def self.where_clause(io, query)
        return unless query.tree
        io << "WHERE " << query.tree.not_nil!.to_sql << "\n"
      end

      def self.limit_clause(io, query)
        io << "LIMIT " << query._limit << "\n" if query._limit
        io << "OFFSET " << query._offset << "\n" if query._offset
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

      def self.parse_query(query, args)
        arr = [] of String
        args.each do
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
