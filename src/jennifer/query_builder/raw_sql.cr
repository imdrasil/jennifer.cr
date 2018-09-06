module Jennifer
  module QueryBuilder
    class RawSql < Criteria
      @field : String
      @params : Array(DBAny)
      @use_brackets : Bool

      def_clone

      def initialize(@field, args : Array = [] of DBAny, @use_brackets = true)
        raise AmbiguousSQL.new(@field) if @field =~ /%[^s]/
        @table = ""
        @params = args.map { |e| e.as(DBAny) }
      end

      def initialize(@field, @use_brackets)
        @table = ""
        @params = [] of DBAny
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

      def filterable?
        @params.any?
      end
    end
  end
end
