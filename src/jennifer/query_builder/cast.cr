module Jennifer::QueryBuilder
  # SQL `CAST` expression.
  class Cast < SQLNode
    getter expression : SQLNode, type : String

    delegate sql_args, filterable?, set_relation, alias_tables, change_table, to: expression

    def initialize(@expression, @type)
    end

    def_clone

    def as_sql(generator)
      generator.cast_expression(expression, type)
    end
  end
end
