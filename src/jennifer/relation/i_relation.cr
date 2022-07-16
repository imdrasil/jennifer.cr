module Jennifer
  module Relation
    # Relation interface.
    abstract class IRelation
      abstract def table_name
      abstract def model_class
      abstract def join_query
      abstract def join_condition(query, type)

      # Returns query for given primary field values
      abstract def query(primary_value_or_array)

      # Preloads relation into *collection* from *out_collection* depending on keys from *pk_repo*.
      abstract def preload_relation(collection, out_collection : Array(Model::Resource), pk_repo)
    end
  end
end
