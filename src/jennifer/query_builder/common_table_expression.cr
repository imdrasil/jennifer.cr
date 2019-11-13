module Jennifer::QueryBuilder
  # Presents single common table expression.
  class CommonTableExpression
    # Expression name.
    getter name

    # Expression query.
    getter query

    def initialize(@name : String, @query : Query, @is_recursive : Bool)
    end

    def_clone

    delegate :filterable?, :sql_args, to: :query

    # Returns whether expression is recursive.
    def recursive?
      @is_recursive
    end
  end
end
