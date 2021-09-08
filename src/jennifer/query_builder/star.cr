module Jennifer
  module QueryBuilder
    # Presents SQL star identifier.
    #
    # Aka `users.*`.
    class Star < Criteria
      def initialize(@table : String)
        @field = "*"
      end

      def identifier(sql_generator)
        "#{sql_generator.quote_table(table)}.*"
      end
    end
  end
end
