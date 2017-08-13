module Jennifer
  module Adapter
    module SqlNotation
      def insert(obj : Model::Base, with_primary_field = true)
        opts = obj.arguments_to_insert
        String.build do |s|
          s << "INSERT INTO " << obj.class.table_name << "("
          opts[:fields].join(", ", s)
          s << ") VALUES (" << Adapter.adapter_class.escape_string(opts[:fields].size) << ") "
          if with_primary_field
            s << " RETURNING " << obj.class.primary_field_name
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

      def parse_query(q)
        q
      end
    end
  end
end
