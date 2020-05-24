module Jennifer
  module QueryBuilder
    # Container for the `ALL` SQL expression.
    class All < SQLNode
      getter query : Query

      def_clone

      def initialize(@query)
      end

      def filterable?
        query.filterable?
      end

      def as_sql(generator)
        "ALL (#{@query.as_sql(generator)})"
      end

      def sql_args(*args, **options) : Array(DBAny)
        query.sql_args(*args, **options)
      end
    end
  end
end
