module Jennifer
  module QueryBuilder
    module Statement
      # Converts node to SQL using *generator* SQLGenerator.
      abstract def as_sql(generator)

      # Returns array of SQL query arguments.
      abstract def sql_args : Array(DBAny)

      # Returns whether node has an argument to be added to SQL statement arguments.
      abstract def filterable?
    end
  end
end
