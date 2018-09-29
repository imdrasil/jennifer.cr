module Jennifer
  module QueryBuilder
    abstract class SQLNode
      # Converts node to SQL using *sql_generator* SQLGenerator.
      abstract def as_sql(sql_generator)

      # Returns array of SQL query arguments.
      abstract def sql_args : Array

      # Returns whether node has an argument to be added to sql statement arguments.
      abstract def filterable?

      def eql?(other)
        false
      end

      # Converts node to SQL using default adaptor.
      def as_sql
        as_sql(Adapter.default_adapter.sql_generator)
      end

      def set_relation(table, name)
      end

      def alias_tables(aliases)
      end

      def change_table(old_name, new_name)
      end
    end
  end
end
