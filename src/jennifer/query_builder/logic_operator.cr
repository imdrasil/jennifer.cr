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
        to_sql
      end

      def alias_tables(aliases)
        @parts.each(&.alias_tables(aliases))
      end

      def set_relation(table, name)
        @parts.each(&.set_relation(table, name))
      end

      def change_table(old_name, new_name)
        @parts.each(&.change_table(old_name, new_name))
      end

      def to_sql
        "(" + @parts.map(&.to_sql).join(" #{operator} ") + ")"
      end

      def sql_args : Array(DB::Any)
        @parts.flat_map(&.sql_args)
      end

      def ==(other : LogicOperator)
        @parts == other.parts
      end
    end

    class And < LogicOperator
      OPERATOR = "AND"

      def &(other : LogicOperator | Criteria)
        add(other)
        self
      end

      def operator
        OPERATOR
      end
    end

    class Or < LogicOperator
      OPERATOR = "OR"

      def |(other : Criteria | LogicOperator)
        add(other)
        self
      end

      def operator
        OPERATOR
      end
    end

    class Xor < LogicOperator
      OPERATOR = "XOR"

      def operator
        OPERATOR
      end
    end
  end
end
