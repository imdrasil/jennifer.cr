module Jennifer
  module Adapter
    abstract class BaseSQLGenerator
      ARRAY_ESCAPE           = "\\\\\\\\"
      ARGUMENT_ESCAPE_STRING = "%s"

      module ClassMethods
        # Generates query for inserting new record to db
        abstract def insert(obj : Model::Base)
        abstract def json_path(path : QueryBuilder::JSONSelector)
      end

      extend ClassMethods

      # Generates insert query
      def self.insert(table, hash)
        String.build do |s|
          s << "INSERT INTO " << table << "("
          hash.keys.join(", ", s)
          s << ") VALUES (" << escape_string(hash.size) << ")"
        end
      end

      def self.bulk_insert(table : String, field_names : Array(String), rows : Int32)
        String.build do |s|
          s << "INSERT INTO " << table << "("
          field_names.join(", ", s) { |e| s << e }
          escaped_row = "(" + escape_string(field_names.size) + ")"
          s << ") VALUES "
          rows.times.join(", ", s) { s << escaped_row }
        end
      end

      # Generates common select sql request
      def self.select(query, exact_fields = [] of String)
        String.build do |s|
          select_clause(s, query, exact_fields)
          body_section(s, query)
        end
      end

      def self.truncate(table : String)
        "TRUNCATE #{table}"
      end

      # TODO: unify method generating - #parse_query should be called here or by caller
      def self.delete(query)
        parse_query(
          String.build do |s|
            s << "DELETE "
            from_clause(s, query)
            body_section(s, query)
          end,
          query.select_args
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
          query.select_args
        )
      end

      def self.count(query)
        parse_query(
          String.build do |s|
            s << "SELECT COUNT(*) "
            from_clause(s, query)
            body_section(s, query)
          end,
          query.select_args
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
        esc = escape_string(1)
        String.build do |s|
          s << "UPDATE " << query.table << " SET "
          options.map { |k, v| "#{k.to_s}= #{esc}" }.join(", ", s)
          s << ' '
          body_section(s, query)
        end
      end

      def self.modify(q, modifications : Hash)
        esc = escape_string(1)
        String.build do |s|
          s << "UPDATE " << q.table << " SET "
          modifications.map { |field, value| "#{field.to_s} = #{field.to_s} #{value[:operator]} #{esc}" }.join(", ", s)
          s << ' '
          body_section(s, q)
        end
      end

      # ========== sql clauses ================

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
        return unless query._unions
        query._unions.not_nil!.each do |u|
          io << " UNION " << self.select(u)
        end
      end

      def self.lock_clause(io : String::Builder, query)
        return if query._lock.nil?
        io << (query._lock.is_a?(String) ? query._lock : " FOR UPDATE ")
      end

      # Renders SELECT and FROM parts
      def self.select_clause(io : String::Builder, query, exact_fields : Array = [] of String)
        io << "SELECT "
        io << "DISTINCT " if query._distinct
        if !query._raw_select
          table = query._table
          if !exact_fields.empty?
            exact_fields.join(", ", io) { |f| io << "#{table}.#{f}" }
          else
            query._select_fields.not_nil!.join(", ", io) { |f| io << f.definition(self) }
          end
        else
          io << query._raw_select.not_nil!
        end
        io << ' '

        from_clause(io, query)
      end

      def self.from_clause(io : String::Builder, query, from = nil)
        io << "FROM "
        return io << (from || query._table) << ' ' unless query._from
        io << "( " <<
          if query._from.is_a?(String)
            query._from
          else
            if query.is_a?(QueryBuilder::ModelQuery)
              self.select(query._from.as(QueryBuilder::ModelQuery))
            else
              self.select(query._from.as(QueryBuilder::Query))
            end
          end
        io << " ) "
      end

      def self.group_clause(io : String::Builder, query)
        return if !query._groups || query._groups.empty?
        io << "GROUP BY "
        query._groups.not_nil!.each.join(", ", io) { |c| io << c.as_sql(self) }
        io << ' '
      end

      def self.having_clause(io : String::Builder, query)
        return unless query._having
        io << "HAVING " << query._having.not_nil!.as_sql(self) << ' '
      end

      def self.join_clause(io : String::Builder, query)
        return unless query._joins
        query._joins.not_nil!.join(" ", io) { |j| io << j.as_sql(self) }
      end

      def self.where_clause(io : String::Builder, query : QueryBuilder::Query | QueryBuilder::ModelQuery)
        where_clause(io, query.tree.not_nil!) if query.tree
      end

      def self.where_clause(io : String::Builder, tree)
        return unless tree
        io << "WHERE " << tree.not_nil!.as_sql(self) << ' '
      end

      def self.limit_clause(io : String::Builder, query)
        io.print "LIMIT ", query._limit.not_nil!, ' ' if query._limit
        io.print "OFFSET ", query._offset.not_nil!, ' ' if query._offset
      end

      def self.order_clause(io : String::Builder, query)
        return if !query._order || query._order.empty?
        io << "ORDER BY "
        query._order.join(", ", io) { |(k, v), _| io.print k.as_sql(self), ' ', v.upcase }
        io << ' '
      end

      # ======== utils

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

      def self.quote(value : Nil)
        "NULL"
      end

      def self.quote(value : Bool)
        value ? "TRUE" : "FALSE"
      end

      def self.quote(value : Int32 | Int16 | Float64 | Float32)
        value.to_s
      end

      def self.escape_string
        ARGUMENT_ESCAPE_STRING
      end

      def self.escape_string(size : Int32)
        case size
        when 1
          ARGUMENT_ESCAPE_STRING
        when 2
          "#{ARGUMENT_ESCAPE_STRING}, #{ARGUMENT_ESCAPE_STRING}"
        when 3
          "#{ARGUMENT_ESCAPE_STRING}, #{ARGUMENT_ESCAPE_STRING}, #{ARGUMENT_ESCAPE_STRING}"
        else
          size.times.join(", ") { ARGUMENT_ESCAPE_STRING }
        end
      end

      def self.filter_out(arg : Array, single : Bool = true)
        single ? escape_string : arg.join(", ") { |a| filter_out(a) }
      end

      def self.filter_out(arg : QueryBuilder::SQLNode)
        arg.as_sql(self)
      end

      def self.filter_out(arg)
        escape_string
      end

      # TODO: optimize array initializing
      def self.parse_query(query : String, args : Array(DBAny))
        args.each_with_index do |arg, i|
          args[i] = arg.as(Time).to_utc if arg.is_a?(Time)
        end
        {query % Array.new(args.size, "?"), args}
      end
    end
  end
end
