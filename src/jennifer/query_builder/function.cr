module Jennifer
  module QueryBuilder
    # Presents SQL function invocation.
    #
    # ```
    # Jennifer::Query["users"].where { coalesce(sql("NULL"), _name) == "John" }
    #
    # # SELECT users. FROM users WHERE COALESCE(NULL, users.name) == "John"
    # ```
    abstract class Function < Criteria
      # Array of arguments that were passed to the function.
      getter operands = [] of Criteria::Rightable

      def initialize(*args)
        @field = ""
        @table = ""
        args.each do |arg|
          operands << arg.as(Criteria::Rightable)
        end
      end

      def definition(generator)
        identifier = as_sql(generator)
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

      def sql_args : Array(DBAny)
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

      # Translates all operands to SQL using *generator*.
      #
      # ```
      # def as_sql(generator)
      #   "CONCAT(#{operands_to_sql(generator)})"
      # end
      # ```
      def operands_to_sql(generator)
        operands.join(", ") do |operand|
          operand_sql(operand, generator)
        end
      end

      # Translates given SQL node to SQL using *generator*.
      #
      # ```
      # def as_sql(generator)
      #   "ABS(#{operand_sql(operands[0], generator)})"
      # end
      # ```
      def operand_sql(operand : SQLNode, generator)
        operand.as_sql(generator)
      end

      # Translates given literal to SQL using *generator*.
      #
      # ```
      # def as_sql(generator)
      #   "ABS(#{operand_sql(operands[0], generator)})"
      # end
      # ```
      def operand_sql(_operand, generator)
        generator.escape_string
      end

      # Defines new function class.
      # - `name` - function name; use used to generate function class name if it isn't specified
      # - `klass` - function class name; optional
      # - `arity` - describes function arity
      # - `comment` - adds given comment to the generated function class.
      #
      # `arity` = -1 means function can accept variable number of argument, 0 - no one.
      #
      # In the block you can define any methods you like but must implement `#as_sql` abstract method.
      #
      # To access arguments passed to the function use `#operands` method.
      #
      # ```
      # Function.define("lower", arity: 1, comment: <<-TEXT
      #   Creates `LOWER` SQL function instance with the given
      #
      #   next line
      #
      #   ```
      #   1 + 2
      #   ```
      #   TEXT
      # ) do
      #   def as_sql(generator)
      #     "LOWER(#{operand_sql(operands[0], generator)})"
      #   end
      # end
      # ```
      macro define(name, klass = nil, arity = 0, comment = nil)
        {%
          klass = name.camelcase + "Function" if klass == nil
          args_string = (
            arity > 0 ? (0...arity).to_a.map { |i| "arg#{i}" }.join(", ") : arity < 0 ? "*args" : ""
          ).id
        %}

        class ::Jennifer::QueryBuilder::ExpressionBuilder
          # Create `{{klass}}` function.
          def {{name.id}}({{args_string}})
            {{klass.id}}.new({{args_string}})
          end
        end

        {{ comment.split("\n").map { |row| "# " + row.strip }.join("\n").id if comment != nil }}
        class {{klass.id}} < ::Jennifer::QueryBuilder::Function
          def_clone

          protected def initialize_copy(other)
            @operands = other.@operands.dup
          end

          {{yield}}
        end
      end
    end

    Function.define(:coalesce, arity: -1, comment: <<-TEXT
      Returns the first non-null argument in a list

      ```
      Jennifer::Query["users"].where { coalesce(nil, sql("NULL"), _name) }
      ```
      TEXT
    ) do
      def as_sql(generator)
        "COALESCE(#{operands_to_sql(generator)})"
      end
    end

    Function.define("lower", arity: 1, comment: <<-TEXT
      Converts the argument to lower-case.

      ```
      Jennifer::Query["users"].where { lower(_name) == "john" }
      ```
      TEXT
    ) do
      def as_sql(generator)
        "LOWER(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("upper", arity: 1, comment: <<-TEXT
      Converts the argument to upper-case.

      ```
      Jennifer::Query["users"].where { upper(_name) == "JOHN" }
      ```
      TEXT
    ) do
      def as_sql(generator)
        "UPPER(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("current_timestamp", comment: "Returns the current date and time.") do
      def as_sql(generator)
        "CURRENT_TIMESTAMP"
      end
    end

    Function.define("current_date", comment: "Returns the current date.") do
      def as_sql(generator)
        "CURRENT_DATE"
      end
    end

    Function.define("current_time", comment: "Returns the current time.") do
      def as_sql(generator)
        "CURRENT_TIME"
      end
    end

    Function.define("now", comment: "Returns current date and time.") do
      def as_sql(generator)
        "NOW()"
      end
    end

    Function.define("concat", arity: -1, comment: <<-TEXT
      Concatenates all arguments into one string.

      ```
      Jennifer::Query["users"].select { [concat(_name, " ", _surname)] }
      ```
      TEXT
    ) do
      def as_sql(generator)
        "CONCAT(#{operands_to_sql(generator)})"
      end
    end

    Function.define("concat_ws", arity: -1, comment: <<-TEXT
      Concatenates all arguments starting from the 2nd into one string using the 1st one as a separator.

      ```
      Jennifer::Query["users"].select { [concat_ws(" ", _name, _middle_name, _surname)] }
      ```
      TEXT
    ) do
      def as_sql(generator)
        "CONCAT_WS(#{operands_to_sql(generator)})"
      end
    end

    Function.define("abs", arity: 1, comment: "Returns the absolute value of an argument.") do
      def as_sql(generator)
        "ABS(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("ceil", arity: 1, comment: <<-TEXT
      Returns the smallest integer value that is greater than or equal to argument.

      ```
      Jennifer::Query["users"].where { ceil(_rating) > 4 }
      ```
      TEXT
    ) do
      def as_sql(generator)
        "CEIL(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("floor", arity: 1, comment: <<-TEXT
      Returns the largest integer value that is less than or equal to argument.

      ```
      Jennifer::Query["users"].where { floor(_rating) > 4 }
      ```
      TEXT
    ) do
      def as_sql(generator)
        "FLOOR(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("count", arity: -1, comment: <<-TEXT
      Returns the count of given field.

      If no argument is specified - `*` is used by default

      ```
      Jennifer::Query["users"].select { [_gender, count.alias("human_count")] }.group(:gender)
      ```
      TEXT
    ) do
      def as_sql(generator)
        identifier =
          if operands.empty?
            "*"
          else
            operand_sql(operands[0], generator)
          end
        "COUNT(#{identifier})"
      end
    end

    Function.define("max", arity: 1, comment: <<-TEXT
      Returns the maximum value of given field.

      ```
      Jennifer::Query["users"].select { [_gender, max(_age).alias("human_age")] }.group(:gender)
      ```
      TEXT
    ) do
      def as_sql(generator)
        "MAX(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("min", arity: 1, comment: <<-TEXT
      Returns the minimum value of given field.

      ```
      Jennifer::Query["users"].select { [_gender, min(_age).alias("human_age")] }.group(:gender)
      ```
      TEXT
    ) do
      def as_sql(generator)
        "MIN(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("sum", arity: 1, comment: <<-TEXT
      Returns the sum of given field values.

      ```
      Jennifer::Query["users"].select { [_gender, sum(_age).alias("human_age")] }.group(:gender)
      ```
      TEXT
    ) do
      def as_sql(generator)
        "SUM(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("avg", arity: 1, comment: <<-TEXT
      Returns the average of given field values.

      ```
      Jennifer::Query["users"].select { [_gender, avg(_age).alias("human_age")] }.group(:gender)
      ```
      TEXT
    ) do
      def as_sql(generator)
        "AVG(#{operand_sql(operands[0], generator)})"
      end
    end

    Function.define("round", arity: -1, comment: <<-TEXT
      Returns the rounded value of given first argument to a specific number of decimal places.

      By default, it rounds to the closes integer.

      ```
      Jennifer::Query["users"].where { round(_rating) > 4 }
      Jennifer::Query["users"].where { round(_rating, 1) > 4.5 }
      ```
      TEXT
    ) do
      def as_sql(generator)
        String.build do |io|
          io << "ROUND("
          io << operand_sql(operands[0], generator)
          if operands.size > 1
            io << ", " << operand_sql(operands[1], generator)
          end
          io << ')'
        end
      end
    end
  end
end
