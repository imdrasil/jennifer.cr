module Jennifer
  module Relation
    abstract class IRelation
      extend Ifrit

      abstract def name
      abstract def table_name
      abstract def model_class
      abstract def join_query
      abstract def condition_clause
      abstract def condition_clause(a)
      abstract def join_condition(a, b)
      abstract def query(a)
      abstract def insert(a, b)
      # Preloads relation into *collection* from *out_collection* depending on keys from *pk_repo*.
      abstract def preload_relation(collection, out_collection, pk_repo)
    end

    # T - related model
    # Q - parent model
    class Base(T, Q) < IRelation
      getter join_query : QueryBuilder::Condition | QueryBuilder::LogicOperator?
      getter foreign : String?, primary : String?, through : Symbol?
      getter name : String

      def initialize(@name, foreign : String | Symbol?, primary : String | Symbol?, query : QueryBuilder::Query, @through = nil)
        @foreign = foreign.to_s if foreign
        @primary = primary.to_s if primary
        @join_query = query.tree
        @join_query.not_nil!.set_relation(T.table_name, @name) if @join_query
      end

      def model_class
        T
      end

      def adapter
        Q.adapter
      end

      def condition_clause
        _foreign = foreign_field
        _primary = primary_field
        tree = T.c(_foreign, @name) == Q.c(_primary)
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def condition_clause(id)
        tree = T.c(foreign_field) == id
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def condition_clause(ids : Array)
        tree = T.c(foreign_field).in(ids)
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def join_condition(query, type)
        this = self
        query.join(model_class, type: type, relation: @name) do |eb|
          this.condition_clause.not_nil!
        end
      end

      # Returns query for given primary field values
      def query(primary_value)
        condition = condition_clause(primary_value)
        T.where { condition }
      end

      def insert(obj : Q, rel : Hash(String, Jennifer::DBAny))
        rel[foreign_field] = obj.attribute(primary_field)
        T.create!(rel)
      end

      def insert(obj : Q, rel : Hash(Symbol, Jennifer::DBAny))
        insert(obj, stringify_hash(rel, Jennifer::DBAny))
      end

      def insert(obj : Q, rel : T)
        rel.set_attribute(foreign_field, obj.attribute(primary_field))
        rel.save!
        rel
      end

      def remove(obj : Q, rel : T)
        rel.update_column(foreign_field, nil) if rel.attribute(foreign_field) == obj.attribute(primary_field)
        rel
      end

      def table_name
        T.table_name
      end

      # Foreign key on ~T~ model side
      def foreign_field
        @foreign ||= Q.foreign_key_name
      end

      def primary_field
        @primary ||= Q.primary_field_name
      end

      def preload_relation(collection, out_collection : Array(Model::Resource), pk_repo)
        return if collection.empty?

        unless pk_repo.has_key?(primary_field)
          array = pk_repo[primary_field] = Array(DBAny).new(collection.size)
          collection.each { |e| array << e.attribute(primary_field) }
        end

        new_collection = query(pk_repo[primary_field]).db_results

        name = self.name
        if new_collection.empty?
          collection.each(&.relation_retrieved(name))
        else
          primary_fields = pk_repo[primary_field]
          collection.each_with_index do |mod, i|
            pv = primary_fields[i]
            # TODO: check if deleting elements from array will increase performance
            new_collection.each { |hash| out_collection << mod.append_relation(name, hash) if hash[foreign_field] == pv }
          end
        end
      end
    end
  end
end
