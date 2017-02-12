module Jennifer
  module QueryBuilder
    abstract class LogicOperator
      def initialize
        @parts = [] of LogicOperator | Criteria
      end

      protected def parts
        @parts
      end

      def add(other : LogicOperator | Criteria)
        @parts << other
      end

      def &(other : Criteria | LogicOperator)
        op = And.new
        op.add(self)
        op.add(other)
        op
      end

      def |(other : Criteria | LogicOperator)
        op = Or.new
        op.add(self)
        op.add(other)
        op
      end

      abstract def operator

      def to_s
        "(" + @parts.map(&.to_s).join(" #{operator} ") + ")"
      end

      def to_sql
        to_s
      end

      def sql_args : Array(DB::Any)
        @parts.flat_map(&.sql_args)
      end

      def ==(other : LogicOperator)
        @parts == other.parts
      end
    end

    class And < LogicOperator
      def &(other : LogicOperator | Criteria)
        add(other)
        self
      end

      def operator
        "AND"
      end
    end

    class Or < LogicOperator
      def |(other : Criteria | LogicOperator)
        add(other)
        self
      end

      def operator
        "OR"
      end
    end

    class Xor < LogicOperator
      def operator
        "XOR"
      end
    end
  end
end
