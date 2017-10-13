module Jennifer
  module QueryBuilder
    class Grouping < SQLNode
      include LogicOperator::Operators

      getter condition : LogicOperator

      def_clone

      delegate sql_args, sql_args_count, to: @condition

      def initialize(@condition)
      end

      def as_sql
        "(" + @condition.as_sql + ")"
      end
    end
  end
end
