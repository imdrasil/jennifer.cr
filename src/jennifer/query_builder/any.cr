module Jennifer
  module QueryBuilder
    class Any < SQLNode
      getter query : Query
      delegate sql_args, sql_args_count, to: @query

      def_clone

      def initialize(@query)
      end

      def as_sql
        "ANY (#{@query.to_sql})"
      end
    end
  end
end
