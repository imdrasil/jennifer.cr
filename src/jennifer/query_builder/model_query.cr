require "./i_model_query"

module Jennifer
  module QueryBuilder
    class ModelQuery(T) < IModelQuery
      @preload_relations : Array(String)

      def initialize
        @preload_relations = [] of String
        super
      end

      def initialize(table, adapter)
        @preload_relations = [] of String
        super(table, adapter)
      end

      protected def initialize_copy_without(other, except : Array(String))
        super(other, except)
        # @eager_load = false
        # @include_relations = false
        @preload_relations = [] of String
      end

      def clone
        clone = {{@type}}.allocate
        clone.initialize_copy(self)
        clone
      end

      protected def initialize_copy(other)
        super(other)
        @eager_load = other.@eager_load
        @include_relations = other.@include_relations
        @nested_relation_tree = other.@nested_relation_tree.clone
        @preload_relations = other.@preload_relations.clone
      end

      protected def preload_relations
        @preload_relations
      end

      def model_class
        T
      end

      def nested_relation_tree : NestedRelationTree
        @nested_relation_tree ||= NestedRelationTree.new(T)
      end

      def multi_query_relation_tree
        @multi_query_relation_tree ||= MultiQueryRelationTree.new(T)
      end

      # Perform search using given plain query and arguments and builds ` but also allow to preload
      # related records using `#preload` method nad respects `#none`
      def find_by_sql(query : String, args : Array(DBAny) = [] of DBAny)
        results = [] of T
        return results if do_nothing?

        read_adapter.query(query, args) do |rs|
          begin
            rs.each { results << T.new(rs) }
          rescue e : Exception
            rs.read_to_end
            raise e
          end
        end
        add_preloaded(results)
      end

      # Executes request and maps result set to objects with loading any requested related objects
      def to_a
        return [] of T if do_nothing?

        add_aliases if @relation_used
        return to_a_with_relations if @eager_load

        result = [] of T
        read_adapter.select(self) do |rs|
          rs.each do
            begin
              result << T.new(rs)
            rescue e : Exception
              rs.read_to_end
              raise e
            end
          end
        end
        add_preloaded(result)
      end

      # Perform request and maps resultset to objects and related objects grepping fields from joined tables; preloading also
      # are performed
      private def to_a_with_relations
        result = read_adapter.select(self) do |rs|
          nested_relation_tree.read(rs, T)
        end
        add_preloaded(result)
      end
    end
  end
end
