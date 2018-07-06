module Jennifer
  module QueryBuilder
    module EagerLoading
      @eager_load : Bool  = false
      @include_relations : Bool = false

      abstract def nested_relation_tree : NestedRelationTree
      abstract def multi_query_relation_tree
      protected abstract def preload_relations

      def _select_fields : Array(Criteria)
        if @select_fields.empty?
          if @eager_load
            nested_relation_tree.select_fields(self)
          else
            [@expression.star] of Criteria
          end
        else
          @select_fields
        end
      end

      def with(*arr)
        self.with(arr.to_a.map(&.to_s))
      end

      def with(arr : Array)
        raise BaseException.new("#with should be called after correspond join") unless @joins
        arr.each do |name|
          table_name = model_class.relation(name).table_name
          temp_joins = _joins!.select { |j| j.table == table_name }
          join = temp_joins.find(&.relation.nil?)
          if join
            join.not_nil!.relation = name
          elsif temp_joins.size == 0
            raise BaseException.new("#with should be called after correspond join: no such table \"#{table_name}\" of relation \"#{name}\"")
          end
          @eager_load = true
          nested_relation_tree.add_relation(name)
        end
        self
      end

      def includes(*names, **deep_relations)
        @include_relations = true

        names.each do |name|
          multi_query_relation_tree.add_relation(self, name)
        end

        deep_relations.each do |rel, nested_rel|
          multi_query_relation_tree.add_deep_relation(self, rel, nested_rel)
        end
        self
      end

      # Alias for includes
      def preload(*names, **deep_relations)
        includes(*names, **deep_relations)
      end

      # Adds to select statement given relations (with correspond joins) and loads them from result
      def eager_load(*names, **deep_relations)
        @eager_load = true

        names.each do |name|
          nested_relation_tree.add_relation(self, name)
        end

        deep_relations.each do |rel, nested_rel|
          nested_relation_tree.add_deep_relation(self, rel, nested_rel)
        end
        self
      end

      # Loads relations added by `preload` method; makes one separate request per each relation
      private def add_preloaded(collection)
        return collection if collection.empty? || !@include_relations
        multi_query_relation_tree.preload(collection)
        collection
      end
    end
  end
end
