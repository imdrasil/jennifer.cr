module Jennifer
  module Relation
    # Relation interface.
    abstract class IRelation
      abstract def table_name
      abstract def model_class
      abstract def join_query
      abstract def condition_clause
      abstract def condition_clause(a)
      abstract def join_condition(a, b)

      # Returns query for given primary field values
      abstract def query(primary_value)
      abstract def insert(a, b)

      # Preloads relation into *collection* from *out_collection* depending on keys from *pk_repo*.
      abstract def preload_relation(collection, out_collection, pk_repo)
    end
  end
end
