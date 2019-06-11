module Jennifer
  module QueryBuilder
    # Includes methods required for associations eager loading.
    #
    # Eager loading is a way to find objects of a certain class and a number of named associations.
    # It is one of the easiest ways to prevent the dreaded N+1 problem in which fetching 100 posts
    # that each need to display their author triggers 101 database queries. Through the use of eager
    # loading, the number of queries will be reduced from 101 to 2.
    module EagerLoading
      @eager_load : Bool = false
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

      # Mark recently added join to be used to retrieve for relations given in *names*.
      #
      # This allows to specify custom JOIN and load results into specified relation.
      #
      # ```
      # Contact.all.join(Address) { and(Address._contact_id == Contact._id, Address._main) }.with_relation([:addresses])
      # ```
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

      # Specify relationships to be included in the result set.
      #
      # All specified relationships are loaded in a separate queries.
      #
      # ```
      # Contact.all.includes(:addresses)
      # Contact.all.includes(:addresses, friends: %i(addresses followers))
      # ```
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

      # Adds to select statement given relations (with corresponding `LEFT OUTER JOIN`) and loads them from results.
      #
      # ```
      # Contact.all.eager_load(:addresses)
      # # SELECT contacts.*, addresses.*
      # # FROM users
      # # LEFT JOIN addresses ON addresses.contact_id = contacts.id
      # ```
      #
      # You can specify nested relationships same way as in `#includes`:
      #
      # ```
      # Contact.all.includes(:addresses, friends: %i(addresses followers))
      # ```
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
