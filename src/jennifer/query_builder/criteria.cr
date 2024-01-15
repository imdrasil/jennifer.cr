require "./json_selector"
require "./order_expression"

module Jennifer
  module QueryBuilder
    # Basic class describing filterable/selectable database atom. By default it is table column.
    class Criteria < SQLNode
      alias Rightable = SQLNode | DBAny | Array(DBAny)

      @ident : String?

      getter relation : String?, alias : String?, field : String, table : String

      def_clone

      def initialize(@field : String, @table : String, @relation = nil)
      end

      def_hash @field, @table

      def eql?(other : Criteria)
        field == other.field &&
          table == other.table &&
          relation == other.relation &&
          self.alias == other.alias
      end

      def set_relation(table : String, name : String)
        @relation = name if @relation.nil? && @table == table
      end

      def alias_tables(aliases : Hash(String, String))
        @table = aliases[@relation.as(String)] if @relation
      end

      def change_table(old_name : String, new_name : String)
        return if @table != old_name

        @table = new_name
        @relation = nil
      end

      # Specifies identifier alias
      #
      # `nil` value disable alias.
      def alias(name : String?)
        @alias = name
        self
      end

      def path(elements : String)
        JSONSelector.new(self, elements, :path)
      end

      def take(key : String | Number)
        JSONSelector.new(self, key, :take)
      end

      def [](key)
        take(key)
      end

      {% for op in %i(< > <= >= + - * / regexp not_regexp like not_like ilike) %}
        def {{op.id}}(value : Rightable)
          Condition.new(self, {{op}}, value)
        end
      {% end %}

      def =~(value : String)
        regexp(value)
      end

      def ==(value : Symbol) # ameba:disable Naming/BinaryOperatorParameterName
        equal(value.to_s)
      end

      def ==(value : Rightable) # ameba:disable Naming/BinaryOperatorParameterName
        equal(value)
      end

      def !=(value : Symbol) # ameba:disable Naming/BinaryOperatorParameterName
        not_equal(value.to_s)
      end

      def !=(value : Rightable) # ameba:disable Naming/BinaryOperatorParameterName
        not_equal(value)
      end

      def equal(value : Rightable)
        # NOTE: here crystal improperly resolves override methods with Nil argument
        if !value.nil?
          Condition.new(self, :==, value)
        else
          is(value)
        end
      end

      def not_equal(value)
        # NOTE: here crystal improperly resolves override methods with Nil argument
        if !value.nil?
          Condition.new(self, :!=, value)
        else
          not(value)
        end
      end

      def between(left : Rightable, right : Rightable)
        Condition.new(self, :between, [left, right] of DBAny)
      end

      def is(value : Symbol | Bool | Nil)
        Condition.new(self, :is, value)
      end

      def not(value : Symbol | Bool | Nil)
        Condition.new(self, :is_not, value)
      end

      def not
        to_condition.not
      end

      def in(arr : Array)
        Condition.new(self, :in, arr.map { |e| e.as(DBAny) })
      end

      def in(arr : SQLNode)
        Condition.new(self, :in, arr)
      end

      def &(other : LogicOperator::Operandable)
        to_condition & other
      end

      def |(other : LogicOperator::Operandable)
        to_condition | other
      end

      def xor(other : LogicOperator::Operandable)
        to_condition.xor(other)
      end

      def to_s(io : IO)
        io << as_sql
      end

      def as_sql(generator) : String
        @ident ||= identifier(generator)
      end

      def identifier : String
        identifier(Adapter.default_adapter.sql_generator)
      end

      def identifier(sql_generator)
        "#{sql_generator.quote_table(table)}.#{sql_generator.quote_identifier(field)}"
      end

      def definition
        definition(Adapter.default_adapter.sql_generator)
      end

      def definition(sql_generator)
        if self.alias
          "#{identifier(sql_generator)} AS #{sql_generator.quote_identifier(self.alias.not_nil!)}"
        else
          identifier(sql_generator)
        end
      end

      def order(direction : String | Symbol)
        order = asc
        order.direction = direction
        order
      end

      def asc
        OrderExpression.new(self, OrderExpression::Direction::ASC)
      end

      def desc
        OrderExpression.new(self, OrderExpression::Direction::DESC)
      end

      def sql_args : Array(DBAny)
        [] of DBAny
      end

      def filterable?
        false
      end
    end
  end
end
