module Jennifer
  module QueryBuilder
    class RawSql < Criteria
      @params : Array(DB::Any)

      def initialize(@field : String, args : Array)
        @table = ""
        @params = args.map { |e| e.as(DB::Any) }
      end

      def alias_tables(aliases); end

      def as_sql
        "(" + @field + ")"
      end

      def sql_args
        @params
      end

      def sql_args_count
        @params.size
      end
    end
  end
end
