require "./json_selector"
require "./criteria_container"

module Jennifer
  module QueryBuilder
    class Criteria < SQLNode
      alias Rightable = SQLNode | DBAny | Array(DBAny)

      @ident : String?

      getter relation : String?, alias : String?, field : String, table : String

      def_clone

      def initialize(@field : String, @table : String, @relation = nil)
      end

      def_hash @field, @table

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

      def ==(value : Symbol)
        self.==(value.to_s)
      end

      def ==(value : Rightable)
        # NOTE: here crystal improperly resolves override methods with Nil argument
        if !value.nil?
          Condition.new(self, :==, value)
        else
          is(value)
        end
      end

      def !=(value : Symbol)
        self.!=(value.to_s)
      end

      def !=(value : Nil)
        not(value)
      end

      def !=(value : Rightable)
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
        Condition.new(self).not
      end

      def in(arr : Array)
        raise ArgumentError.new("IN array can't be empty") if arr.empty?
        Condition.new(self, :in, arr.map { |e| e.as(DBAny) })
      end

      def &(other : LogicOperator::Operandable)
        Condition.new(self) & other
      end

      def |(other : LogicOperator::Operandable)
        Condition.new(self) | other
      end

      def xor(other : LogicOperator::Operandable)
        to_condition.xor(other)
      end

      def to_s
        as_sql
      end

      def as_sql(_generator) : String
        @ident ||= identifier
      end

      def identifier : String
        "#{@table}.#{@field.to_s}"
      end

      def definition
        @alias ? "#{identifier} AS #{@alias}" : identifier
      end

      def definition(_sql_generator)
        definition
      end

      def sql_args : Array(DBAny)
        [] of DBAny
      end

      def filterable?
        false
      end

      def to_condition
        Condition.new(self)
      end
    end
  end
end
