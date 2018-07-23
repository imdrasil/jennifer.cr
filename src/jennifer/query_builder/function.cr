module Jennifer
  module QueryBuilder
    abstract class Function < Criteria
      getter operands = [] of Criteria::Rightable

      def initialize(*args)
        @field = ""
        @table = ""
        args.each do |arg|
          operands << arg.as(Criteria::Rightable)
        end
      end

      def definition(sql_generator)
        identifier = as_sql(sql_generator)
        @alias ? "#{identifier} AS #{@alias}" : identifier
      end

      def definition
        definition(Adapter.default_adapter.sql_generator)
      end

      # NOTE: can't be abstract because is already implemented by super class
      def clone
        raise AbstractMethod.new(:clone, {{@type}})
      end

      def set_relation(table, name)
        operands.each do |operand|
          operand.as(SQLNode).set_relation(table, name) if operand.is_a?(SQLNode)
        end
      end

      def alias_tables(aliases)
        operands.each do |operand|
          if operand.is_a?(SQLNode)
            operand.as(SQLNode).alias_tables(aliases)
          end
        end
      end

      def change_table(old_name, new_name)
        operands.each do |operand|
          operand.as(SQLNode).change_table(old_name, new_name) if operand.is_a?(SQLNode)
        end
      end

      def sql_args
        res = [] of DBAny
        operands.each do |operand|
          if operand.is_a?(SQLNode)
            res.concat(operand.sql_args)
          else
            res << operand.as(DBAny)
          end
        end
        res
      end

      def filterable?
        @operands.any? { |operand| !operand.is_a?(SQLNode) || operand.as(SQLNode).filterable? }
      end

      private def operands_to_sql(generator)
        operands.join(", ") do |operand|
          operand_sql(operand, generator)
        end
      end

      private def operand_sql(operand, generator)
        if operand.is_a?(SQLNode)
          operand.as_sql(generator)
        else
          generator.escape_string
        end
      end

      # Defines new function class.
      # - `name` - function name; use used to generate function class name if it isn't specified
      # - `klass` - function class name; optional
      # - `arity` - describes function arity; -1 stands for any count
      macro define(name, klass = nil, arity = -1)
        {% klass = name.camelcase + "Function" if klass == nil %}
        {% args_string = "*args" %}
        {% if arity > -1 %}
          {% args_string = "" %}
          {% for i in (0...arity) %}
            {% args_string = args_string + ", " if i != 0 %}
            {% args_string = args_string + "arg#{i}" %}
          {% end %}
        {% end %}
        {% args_string = args_string.id %}

        class ::Jennifer::QueryBuilder::ExpressionBuilder
          def {{name.id}}({{args_string}})
            {{klass.id}}.new({{args_string}})
          end
        end

        class {{klass.id}} < ::Jennifer::QueryBuilder::Function
          def_clone

          protected def initialize_copy(other)
            @operands = other.@operands.dup
          end

          {{yield}}
        end
      end
    end

    Function.define("lower", arity: 1) do
      def as_sql(generator)
        "LOWER(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("upper", arity: 1) do
      def as_sql(generator)
        "UPPER(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("current_timestamp", arity: 0) do
      def as_sql(generator)
        "CURRENT_TIMESTAMP"
      end
    end

    Function.define("current_date", arity: 0) do
      def as_sql(generator)
        "CURRENT_DATE"
      end
    end

    Function.define("current_time", arity: 0) do
      def as_sql(generator)
        "CURRENT_TIME"
      end
    end

    Function.define("now", arity: 0) do
      def as_sql(generator)
        "NOW()"
      end
    end

    Function.define("concat") do
      def as_sql(generator)
        "CONCAT(#{operands_to_sql(generator)})"
      end
    end

    Function.define("abs", arity: 1) do
      def as_sql(generator)
        "ABS(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("ceil", arity: 1) do
      def as_sql(generator)
        "CEIL(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("floor", arity: 1) do
      def as_sql(generator)
        "FLOOR(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("round", arity: 1) do
      def as_sql(generator)
        "ROUND(#{operand_sql(operands[0], generator)})"
      end
    end
  end
end
