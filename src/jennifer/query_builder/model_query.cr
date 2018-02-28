require "./i_model_query"

module Jennifer
  module QueryBuilder
    class ModelQuery(T) < IModelQuery
      @preload_relations : Array(String)

      def initialize
        @preload_relations = [] of String
        super
      end

      def initialize(@table)
        initialize
      end

      def initialize_copy_with(other, except : Array(String))
        super
        @eager_load_tree = other.@eager_load_tree.clone
        @eager_load = other.@eager_load.clone
        @preload_relations = [] of String
      end

      def clone
        clone = {{@type}}.allocate
        clone.initialize_copy(self)
        clone
      end

      protected def initialize_copy(other)
        super
        @eager_load_tree = other.@eager_load_tree.clone
        @eager_load = other.@eager_load.clone
        @preload_relations = other.@preload_relations.clone
      end

      protected def preload_relations
        @preload_relations
      end

      def model_class
        T
      end

      def eager_load_tree
        @eager_load_tree ||= RelationNestingTree(T).new
      end

      # Perform search using given plain query and arguments and builds ` but also allow to preload
      # related records using `#preload` method nad respects `#none`
      def find_by_sql(query : String, args : Array(DBAny) = [] of DBAny)
        results = [] of T
        return results if @do_nothing
        adapter.query(query, args) do |rs|
          begin
            rs.each do
              results << T.build(rs)
            end
          rescue e : Exception
            rs.read_to_end
            raise e
          end
        end
        add_preloaded(results)
      end

      # Executes request and maps result set to objects with loading any requested related objects
      def to_a
        return [] of T if @do_nothing
        add_aliases if @relation_used
        return to_a_with_relations if @eager_load
        result = [] of T
        adapter.select(self) do |rs|
          rs.each do
            begin
              result << T.build(rs)
            rescue e : Exception
              rs.read_to_end
              raise e
            end
          end
        end
        add_preloaded(result)
      end

      # TODO: brake this method to smaller ones
      # Perform request and maps results set to objects and related objects grepping fields from joined tables; preloading also
      # are performed
      private def to_a_with_relations
        h_result = {} of DBAny => T

        adapter.select(self) do |rs|
          eager_load_tree.read(rs, h_result)
        end
        add_preloaded(h_result.values)
      end

      private def adapter
        T.adapter
      end
    end
  end
end
