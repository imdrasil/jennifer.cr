module Jennifer
  module QueryBuilder
    abstract class SQLNode
      include Statement

      def to_condition
        Condition.new(self)
      end

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
