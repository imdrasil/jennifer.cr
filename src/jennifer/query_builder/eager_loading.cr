module Jennifer
  module QueryBuilder
    module EagerLoading
      @eager_load : Bool  = false
      @include_relations : Bool = false

      abstract def nested_relation_tree : NestedRelationTree
      abstract def multi_query_relation_tree
      protected abstract def preload_relations

      def _select_fields : Array(Criteria)
        if @select_fields.nil? && @eager_load
          nested_relation_tree.select_fields(self)
        else
          super
        end
      end

      # Mark recently added join to be used to retrieve for relations given in *names*.
      #
      # This allows to specify custom JOIN and load results into specified relation.
      #
      # ```
      # Contact.all.join(Address) { and(Address._contact_id == Contact._id, Address._main) }.with_relation(:addresses)
      # ```
      def with_relation(*names)
        with_relation(names.to_a.map(&.to_s))
      end

      def with_relation(names : Array)
        raise BaseException.new("#with_relation should be called after corresponding join") unless @joins

        join_array = _joins!.reverse
        names.each do |name|
          table_name = model_class.relation(name).table_name
          temp_joins = join_array.select { |j| j.table == table_name }
          join = temp_joins.find(&.relation.nil?)
          if join
            join.not_nil!.relation = name
          elsif temp_joins.empty?
            raise BaseException.new(
              "#with_relation should be called after corresponding join: no such table \"#{table_name}\" of relation \"#{name}\""
            )
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

      # Alias for includes.
      def preload(*names, **deep_relations)
        includes(*names, **deep_relations)
      end

      # Adds to select statement given relations (with correspond joins) and loads them from result.
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

      # Loads relations added by `preload` method; makes one separate request per each relation.
      private def add_preloaded(collection)
        return collection if collection.empty? || !@include_relations
        multi_query_relation_tree.preload(collection)
        collection
      end
    end
  end
end
