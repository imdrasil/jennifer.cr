module Jennifer
  module QueryBuilder
    class RawSql < Criteria
      @field : String
      @params : Array(DB::Any)
      @use_brackets : Bool

      def_clone

      def initialize(@field, args : Array = [] of DB::Any, @use_brackets = true)
        @table = ""
        @params = args.map { |e| e.as(DB::Any) }
      end

      def initialize(@field, @use_brackets)
        @table = ""
        @params = [] of DB::Any
      end

      def with_brackets
        @use_brackets = true
      end

      def without_brackets
        @use_brackets = false
      end

      def alias_tables(aliases); end

      def identifier
        @use_brackets ? "(" + @field + ")" : @field
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
