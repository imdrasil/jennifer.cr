module Jennifer::QueryBuilder
  # SQL `CAST` expression.
  class Cast < SQLNode
    getter expression : SQLNode, type : String

    delegate filterable?, set_relation, alias_tables, change_table, to: expression

    def initialize(@expression, @type)
    end

    def_clone

    def sql_args(*args, **options) : Array(DBAny)
      expression.sql_args(*args, **options)
    end

    def as_sql(generator)
      generator.cast_expression(expression, type)
    end
  end
end
