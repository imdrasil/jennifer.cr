module Jennifer
  module QueryBuilder
    class Join
      @type : Symbol
      property :table, :type, :on

      def initialize(@table : String, @on : Criteria | LogicOperator, @type)
      end

      def to_sql : String
        sql_string =
          case @type
          when :left
            "LEFT JOIN "
          when :right
            "RIGHT JOIN "
          else
            "JOIN "
          end
        sql_string += "#{@table} ON #{@on.to_sql}\n"
      end

      def sql_args
        @on.sql_args
      end
    end
  end
end
