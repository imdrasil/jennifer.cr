require "./json_selector"

module Jennifer
  module QueryBuilder
    class Criteria < SQLNode
      alias Rightable = SQLNode | DBAny | Array(DBAny)

      @ident : String?

      getter relation : String?, alias : String?, field : String, table : String

      def_clone

      def initialize(@field : String, @table : String, @relation = nil)
      end

      # NOTE: workaround for passing criteria to the hash as a key - somewhy any Criteria is realized as same one
      def hash
        object_id.hash
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

      def ==(value : Rightable)
        if !value.nil?
          Condition.new(self, :==, value)
        else
          is(value)
        end
      end

      def !=(value : Symbol)
        self.!=(value.to_s)
      end

      def !=(value : Rightable)
        if !value.nil?
          Condition.new(self, :!=, value)
        else
          not(value)
        end
      end

      def between(left : Rightable, right : Rightable)
        Condition.new(self, :between, Ifrit.typed_array([left, right], DBAny))
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

      def as_sql : String
        @ident ||= identifier
      end

      def identifier : String
        "#{@table}.#{@field.to_s}"
      end

      def definition
        @alias ? "#{identifier} AS #{@alias}" : identifier
      end

      def sql_args : Array(DB::Any)
        [] of DB::Any
      end

      def sql_args_count
        0
      end

      def to_condition
        Condition.new(self)
      end

      private def translate(value : Symbol | Bool | Nil)
        case value
        when nil, true, false
          Adapter::SqlGenerator.quote(value)
        when :unknown
          "UNKNOWN"
        when :nil
          Adapter::SqlGenerator.quote(nil)
        end
      end
    end
  end
end
