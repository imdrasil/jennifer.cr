module Jennifer
  module QueryBuilder
    class RawSql < Criteria
      def initialize(@field : String, @params : Array(DB::Any))
        @table = ""
      end

      def to_sql
        str =
          case @operator
          when :bool
            "#({@field})"
          when :in
            "(#{@field}) IN(#{::Jennifer::Adapter.question_marks(@rhs.as(Array).size)})"
          else
            "(#{@field}) #{@operator.to_s} #{@operator.as(Operator).filterable_rhs? ? filter_out(@rhs) : @rhs}"
          end
        str = "NOT (#{str})" if @negative
        str
      end

      def sql_args
        @params + super
      end
    end
  end
end
