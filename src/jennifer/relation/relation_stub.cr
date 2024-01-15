module Jennifer
  # This is a stub for the case when no relation has been defined yet.

  # :nodoc:
  class RelationStub < ::Jennifer::Relation::IRelation
    def name
      raise "stubbed relation"
    end

    def insert(a, b)
      raise "stubbed relation"
    end

    def join_condition(query, type)
      raise "stubbed relation"
    end

    def join_condition(query, type, &_block)
      raise "stubbed relation"
    end

    def query(primary_value_or_array)
      raise "stubbed relation"
    end

    def condition_clause(a)
      raise "stubbed relation"
    end

    def preload_relation(collection, out_collection, pk_repo)
      raise "stubbed relation"
    end

    {% for method in %i(table_name model_class type set_callback condition_clause foreign_field primary_field join_query) %}
      def {{method.id}}
        raise "stubbed relation"
      end
    {% end %}
  end
end
