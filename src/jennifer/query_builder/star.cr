module Jennifer
  module QueryBuilder
    class Star < Criteria
      def initialize(@table : String)
        @field = "*"
      end
    end
  end
end
