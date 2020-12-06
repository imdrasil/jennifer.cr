require "./i_relation"

module Jennifer
  module Relation
    # Base generic relation class.
    #
    # *T* - related model
    # *Q* - parent model
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
        tree = T.c(foreign_field, @name) == Q.c(primary_field)
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def condition_clause(ids : Array(DBAny))
        tree = T.c(foreign_field, @name).in(ids)
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def condition_clause(id : DBAny)
        tree = T.c(foreign_field, @name) == id
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def join_condition(query, type)
        this = self
        query.join(model_class, type: type, relation: @name) do
          this.condition_clause.not_nil!
        end
      end

      def query(primary_value_or_array)
        condition = condition_clause(primary_value_or_array)
        T.where { condition }
      end

      def insert(obj : Q, rel : Hash(String, T::AttrType))
        rel[foreign_field] = obj.attribute(primary_field).as(T::AttrType)
        T.create!(rel)
      end

      def insert(obj : Q, rel : Hash(Symbol, T::AttrType))
        insert(obj, Ifrit.stringify_hash(rel, T::AttrType))
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

      # Foreign key on *T* model side
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
          collection.each { |e| array << e.attribute_before_typecast(primary_field) }
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
