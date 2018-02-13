module Jennifer
  module QueryBuilder
    abstract class SQLNode
      abstract def as_sql(sql_generator)
      abstract def sql_args : Array

      def as_sql
        as_sql(Adapter.default_adapter.sql_generator)
      end

      def sql_args_count : Int32
        sql_args.size
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
