module Jennifer
  module QueryBuilder
    class Criteria
      alias Rightable = Criteria | DBAny | Array(DBAny)

      getter relation : String?, field, table

      def initialize(@field : String, @table : String, @relation = nil)
      end

      def_clone

      def set_relation(table, name)
        @relation = name if @relation.nil? && @table == table
      end

      def alias_tables(aliases)
        @table = aliases[@relation.as(String)] if @relation
      end

      def change_table(old_name, new_name)
        return if @table != old_name
        @table = new_name
        @relation = nil
      end

      {% for op in [:<, :>, :<=, :>=, :+, :-, :*, :/, :regexp, :not_regexp, :like, :not_like] %}
        def {{op.id}}(value : Rightable)
          Condition.new(self, {{op}}, value)
        end
      {% end %}

      def =~(value : String)
        regexp(value)
      end

      def ==(value : Symbol)
        self.==(value.to_s)
      end

      def !=(value : Symbol)
        self.!=(value.to_s)
      end

      def ==(value : Rightable)
        if !value.nil?
          Condition.new(self, :==, value)
        else
          is(value)
        end
      end

      def !=(value : Rightable)
        if !value.nil?
          Condition.new(self, :!=, value)
        else
          not(value)
        end
      end

      def is(value : Symbol | Bool | Nil)
        Condition.new(self, :is, translate(value))
      end

      def not(value : Symbol | Bool | Nil)
        Condition.new(self, :not, translate(value))
      end

      def not
        Condition.new(self).not
      end

      def in(arr : Array)
        raise ArgumentError.new("IN array can't be empty") if arr.empty?
        Condition.new(self, :in, arr.map { |e| e.as(DBAny) })
      end

      def &(other : Criteria | Condition | LogicOperator)
        Condition.new(self) & other
      end

      def |(other : Criteria | Condition | LogicOperator)
        Condition.new(self) | other
      end

      def to_s
        as_sql
      end

      def as_sql
        "#{@table}.#{@field.to_s}"
      end

      def sql_args
        [] of DBAny
      end

      def sql_args_count
        0
      end

      def to_condition
        Condition.new(self)
      end

      private def translate(value : Symbol | Bool | Nil)
        case value
        when :nil, nil
          "NULL"
        when :unknown
          "UNKNOWN"
        when true
          "TRUE"
        when false
          "FALSE"
        end
      end
    end
  end
end
