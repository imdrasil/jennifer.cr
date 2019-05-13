module Jennifer
  module QueryBuilder
    # Presents SQL star identifier.
    #
    # Aka `users.*`.
    class Star < Criteria
      def initialize(@table : String)
        @field = "*"
      end
    end
  end
end
