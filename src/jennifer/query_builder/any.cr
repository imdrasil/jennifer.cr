module Jennifer
  module QueryBuilder
    class Any < SQLNode
      getter query : Query
      delegate sql_args, to: @query

      def_clone

      def initialize(@query)
      end

      def filterable?
        query.filterable?
      end

      def as_sql(generator)
        "ANY (#{@query.as_sql(generator)})"
      end
    end
  end
end
