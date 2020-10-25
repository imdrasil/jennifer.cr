require "../model/base"
require "set"

module Jennifer
  module QueryBuilder
    abstract class RelationTree
      # First tuple component presents index of parent context; 0 value presents top level collection,
      # any positive value *i* - *i*-th relation in ~bucket~ (with 1-based indexing).
      alias Element = Tuple(Int32, Relation::IRelation)

      getter bucket : Array(Element)

      def initialize(@klass : Model::Resource.class)
        @bucket = [] of Element
      end

      def adapter
        @klass.adapter
      end

      def clone
        clone = {{@type}}.allocate
        clone.initialize_copy(self)
        clone
      end

      protected def initialize_copy(other)
        @bucket = other.@bucket.map { |pair| pair }
        @klass = other.@klass
      end

      def add_relation(rel)
        @bucket << {0, @klass.relation(rel.to_s)}
      end

      abstract def add_relation(query, rel, context, index : Int32)

      def add_deep_relation(query, rel, nested_rel : Symbol, context = @klass, index : Int32 = 0)
        existing_relation_index = find_index_or_add_relation(index, rel.to_s, context, query)

        existing_relation = @bucket[existing_relation_index][1]
        add_relation(query, nested_rel, existing_relation.model_class, existing_relation_index + 1)
      end

      def add_deep_relation(query, rel, nested_rels : Array, context = @klass, index : Int32 = 0)
        nested_rels.each { |nested_rel| add_deep_relation(query, rel, nested_rel, context, index) }
      end

      def add_deep_relation(query, rel, nested_rels : Hash | NamedTuple, context = @klass, index : Int32 = 0)
        new_index = find_index_or_add_relation(index, rel.to_s, context, query)
        new_context = context.relation(rel.to_s).model_class
        nested_rels.each { |name, nested_rel| add_deep_relation(query, name, nested_rel, new_context, new_index + 1) }
      end

      protected def find_existing_relation_index(index, relation_name)
        @bucket.index { |pair| pair[0] == index && pair[1].name == relation_name }
      end

      protected def find_index_or_add_relation(index, rel : String, context, query)
        existing_relation_index = find_existing_relation_index(index, rel.to_s)
        if existing_relation_index
          existing_relation_index
        else
          add_relation(query, rel, context, index)
          @bucket.size - 1
        end
      end
    end
  end
end
