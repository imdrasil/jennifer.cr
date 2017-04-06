module Jennifer
  module QueryBuilder
    class RawSql < Criteria
      @params : Array(DB::Any)

      def initialize(@field : String, args : Array)
        @table = ""
        @params = args.map { |e| e.as(DB::Any) }
      end

      def alias_tables(aliases)
      end

      def to_sql
        str =
          case @operator
          when :bool
            "(#{@field})"
          when :in
            "(#{@field}) IN(#{::Jennifer::Adapter.escape_string(@rhs.as(Array).size)})"
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
