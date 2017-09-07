module Jennifer
  module QueryBuilder
    abstract class LogicOperator
      def initialize
        @parts = [] of LogicOperator | Condition
      end

      protected def parts
        @parts
      end

      def add(other : LogicOperator | Condition)
        @parts << other
      end

      def &(other : Condition | LogicOperator)
        op = And.new
        op.add(self)
        op.add(other)
        op
      end

      def |(other : Condition | LogicOperator)
        op = Or.new
        op.add(self)
        op.add(other)
        op
      end

      abstract def operator

      def to_s
        as_sql
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

      def as_sql
        "(" + @parts.map(&.as_sql).join(" #{operator} ") + ")"
      end

      def sql_args : Array(DB::Any)
        @parts.flat_map(&.sql_args)
      end

      def sql_args_count
        @parts.reduce(0) { |sum, e| sum += e.sql_args_count }
      end

      def ==(other : LogicOperator)
        @parts == other.parts
      end
    end

    class And < LogicOperator
      OPERATOR = "AND"

      def_clone

      protected def initialize_copy(other)
        @parts = other.@parts.dup
      end

      def &(other : LogicOperator | Condition)
        add(other)
        self
      end

      def operator
        OPERATOR
      end
    end

    class Or < LogicOperator
      OPERATOR = "OR"

      def_clone

      protected def initialize_copy(other)
        @parts = other.@parts.dup
      end

      def |(other : Condition | LogicOperator)
        add(other)
        self
      end

      def operator
        OPERATOR
      end
    end

    class Xor < LogicOperator
      OPERATOR = "XOR"

      def_clone

      protected def initialize_copy(other)
        @parts = other.@parts.dup
      end

      def operator
        OPERATOR
      end
    end
  end
end
