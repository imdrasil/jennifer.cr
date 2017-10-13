module Jennifer
  module QueryBuilder
    class Join
      setter table : String | Query
      property type : Symbol, on : Condition | LogicOperator, aliass : String?, relation : String?

      def_clone

      def initialize(@table, on : Criteria, @type, @aliass = nil, @relation = nil)
        @on = on.to_condition
      end

      def initialize(@table, @on : Condition | LogicOperator, @type, @aliass = nil, @relation = nil)
      end

      def table
        @table.is_a?(String) ? @table.as(String) : ""
      end

      def has_alias?
        !@aliass.nil?
      end

      def as_sql
        sql_string =
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

        sql_string + "#{table_definition} ON #{@on.as_sql}\n"
      end

      def table_definition
        @aliass ? "#{table_name} #{@aliass}" : table_name
      end

      def table_name : String
        if @table.is_a?(String)
          @table.as(String)
        else
          "(" + @table.as(Query).to_sql + ")"
        end
      end

      def alias_tables(aliases)
        @aliass = aliases[@relation.as(String)] if @relation && !@aliass
        @on.alias_tables(aliases)
      end

      def sql_args
        @table.is_a?(String) ? @on.sql_args : @table.as(Query).sql_args + @on.sql_args
      end

      def sql_args_count
        @table.is_a?(String) ? @on.sql_args_count : @table.as(Query).sql_args_count + @on.sql_args_count
      end
    end

    class LateralJoin < Join
      def as_sql
        sql_string =
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

        sql_string + "#{table_definition} ON #{@on.as_sql}\n"
      end
    end
  end
end
