module Jennifer
  module Adapter
    module SqlNotation
      def insert(obj : Model::Base, with_primary_field = true)
        opts = obj.arguments_to_insert
        String.build do |s|
          s << "INSERT INTO " << obj.class.table_name
          unless opts[:fields].empty?
            s << "("
            opts[:fields].join(", ", s)
            s << ") VALUES (" << Adapter.adapter_class.escape_string(opts[:fields].size) << ") "
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
      def update(query, options : Hash)
        esc = Adapter.adapter_class.escape_string(1)
        String.build do |s|
          s << "UPDATE " << query.table << " SET "
          options.map { |k, v| "#{k.to_s}= #{esc}" }.join(", ", s)
          s << "\n"
          _joins = query._joins

          from_clause(s, query, _joins[0].table_name) unless _joins.empty?
          where_clause(s, query.tree)
          unless _joins.empty?
            where_clause(s, _joins[0].on)
            _joins[1..-1].map(&.to_sql).join(' ', s)
          end
        end
      end

      def operator_to_sql(operator)
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

      def parse_query(query, arg_count)
        arr = [] of String
        arg_count.times do |i|
          arr << "$#{i + 1}"
        end
        query % arr
      end
    end
  end
end
