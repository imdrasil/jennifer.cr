module Jennifer
  module QueryBuilder
    class All < SQLNode
      getter query : Query
      delegate sql_args, to: @query

      def_clone

      def initialize(@query)
      end

      def filterable?
        query.filterable?
      end

      def as_sql(generator)
        "ALL (#{@query.as_sql(generator)})"
      end
    end
  end
end
