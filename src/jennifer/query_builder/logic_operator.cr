module Jennifer
  module QueryBuilder
    abstract class LogicOperator
      module Operators
        def &(other : Criteria)
          And.new(self, other.to_condition)
        end

        def |(other : Criteria)
          Or.new(self, other.to_condition)
        end

        def xor(other : Criteria)
          Xor.new(self, other.to_condition)
        end

        def &(other : Operandable)
          And.new(self, other)
        end

        def |(other : Operandable)
          Or.new(self, other)
        end

        def xor(other : Operandable)
          Xor.new(self, other)
        end
      end

      include Operators

      alias Operandable = LogicOperator | Condition | Grouping | Criteria

      getter lhs : Operandable, rhs : Operandable

      def initialize(@lhs, @rhs)
      end

      abstract def operator

      def to_s(io : IO)
        io << as_sql
      end

      def alias_tables(aliases)
        @rhs.alias_tables(aliases)
        @lhs.alias_tables(aliases)
      end

      def set_relation(table, name)
        @rhs.set_relation(table, name)
        @lhs.set_relation(table, name)
      end

      def change_table(old_name, new_name)
        @rhs.change_table(old_name, new_name)
        @lhs.change_table(old_name, new_name)
      end

      def as_sql
        as_sql(Adapter.default_adapter.sql_generator)
      end

      def as_sql(generator)
        @lhs.as_sql(generator) + " " + operator + " " + @rhs.as_sql(generator)
      end

      def sql_args : Array(DBAny)
        @lhs.sql_args + @rhs.sql_args
      end

      def filterable?
        @lhs.filterable? || @rhs.filterable?
      end

      def ==(other)
        eql?(other)
      end

      def eql?(other : LogicOperator)
        @lhs.eql?(other.lhs) && @rhs.eql?(other.rhs)
      end

      def eql?(other)
        false
      end
    end

    class And < LogicOperator
      OPERATOR = "AND"

      def_clone

      def operator
        OPERATOR
      end
    end

    class Or < LogicOperator
      OPERATOR = "OR"

      def_clone

      def operator
        OPERATOR
      end
    end

    class Xor < LogicOperator
      OPERATOR = "XOR"

      def_clone

      def operator
        OPERATOR
      end
    end
  end
end
