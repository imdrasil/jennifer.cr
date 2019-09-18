module Jennifer
  module QueryBuilder
    # Presents group of logic operations.
    class Grouping < SQLNode
      include LogicOperator::Operators

      getter condition : LogicOperator | Statement

      def_clone

      def initialize(@condition)
      end

      def eql?(other : Grouping)
        condition.eql?(other.condition)
      end

      def sql_args : Array(DBAny)
        condition.sql_args
      end

      def filterable?
        condition.filterable?
      end

      def as_sql(generator)
        "(" + @condition.as_sql(generator) + ")"
      end
    end
  end
end
