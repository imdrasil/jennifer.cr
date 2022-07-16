module Jennifer::QueryBuilder
  # Present reference to the `VALUES` related to the row with duplicate key during upsert.
  class Values < SQLNode
    def initialize(@field : Symbol)
    end

    def_clone

    {% for op in %i(+ - * /) %}
      def {{op.id}}(value : SQLNode | DBAny)
        Condition.new(self, {{op}}, value)
      end
    {% end %}

    def as_sql(generator)
      generator.values_expression(@field)
    end

    def sql_args : Array(DBAny)
      [] of DBAny
    end

    def filterable?
      false
    end
  end
end
