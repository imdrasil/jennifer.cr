module Jennifer
  module QueryBuilder
    class Join
      # Table name to be joined or source query.
      setter table : String | Query

      # Join type.
      property type : Symbol

      # Query `ON` condition.
      property on : Condition | LogicOperator

      # Table alias.
      property aliass : String?

      property relation : String?

      def_clone

      def initialize(@table, on : Criteria, @type, @aliass = nil, @relation = nil)
        @on = on.to_condition
      end

      def initialize(@table, @on : Condition | LogicOperator, @type, @aliass = nil, @relation = nil)
      end

      def initialize(@table, on : Grouping, @type, @aliass = nil, @relation = nil)
        @on = on.to_condition
      end

      def table
        @table.is_a?(String) ? @table.as(String) : ""
      end

      def has_alias?
        !@aliass.nil?
      end

      def filterable?
        @on.filterable? || (@table.is_a?(Query) && @table.as(Query).filterable?)
      end

      def as_sql
        as_sql(Adapter.default_adapter.sql_generator)
      end

      def as_sql(generator)
        type_definition + "#{table_definition(generator)} ON #{@on.as_sql(generator)}\n"
      end

      def type_definition
        case @type
        when :left
          "LEFT JOIN "
        when :right
          "RIGHT JOIN "
        when :inner
          "JOIN "
        when :full, :full_outer
          "FULL OUTER JOIN "
        else
          raise ArgumentError.new("Bad join type: #{@type}.")
        end
      end

      def table_definition(generator)
        @aliass ? "#{table_name(generator)} #{generator.quote_identifier(@aliass.not_nil!)}" : table_name(generator)
      end

      def table_name(generator) : String
        if @table.is_a?(String)
          generator.quote_table(@table.as(String))
        else
          "(" + @table.as(Query).as_sql(generator) + ")"
        end
      end

      def alias_tables(aliases)
        @aliass = aliases[@relation.as(String)] if @relation && !@aliass
        @on.alias_tables(aliases)
      end

      def sql_args : Array(DBAny)
        @table.is_a?(String) ? @on.sql_args : @table.as(Query).sql_args + @on.sql_args
      end
    end

    class LateralJoin < Join
      def type_definition
        case @type
        when :left
          "LEFT JOIN "
        when :right
          "RIGHT JOIN "
        when :inner
          "JOIN "
        when :full, :full_outer
          "FULL OUTER JOIN "
        else
          raise ArgumentError.new("Bad join type: #{@type}.")
        end + "LATERAL "
      end
    end
  end
end
