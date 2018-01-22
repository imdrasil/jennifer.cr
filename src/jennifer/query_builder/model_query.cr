require "./i_model_query"

module Jennifer
  module QueryBuilder
    class ModelQuery(T) < IModelQuery
      def initialize_copy_with(other, except : Array(String))
        super
        @preload_relations = [] of String
      end

      def clone
        clone = {{@type}}.allocate
        clone.initialize_copy(self)
        clone
      end

      protected def initialize_copy(other)
        super
        @preload_relations = other.@preload_relations.clone
      end

      def model_class
        T
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
        return to_a_with_relations unless @relations.empty?
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
      # are perfomed
      private def to_a_with_relations
        h_result = {} of String => T

        models = @relations.map { |e| T.relation(e).model_class }
        existence = @relations.map { |_| {} of String => Bool }
        adapter.select(self) do |rs|
          rs.each do
            begin
              h = build_hash(rs, T.actual_table_field_count)
              main_field = T.primary_field_name
              if h[main_field]?
                obj = (h_result[h[main_field].to_s] ||= T.build(h, false))
                models.each_with_index do |model, i|
                  h = build_hash(rs, model.actual_table_field_count)
                  pfn = model.primary_field_name
                  if h[pfn].nil? || existence[i][h[pfn].to_s]?
                    (rs.column_count - rs.column_index).times do |i|
                      rs.read
                    end
                    break
                  else
                    existence[i][h[pfn].to_s] = true
                    obj.as(T).append_relation(@relations[i], h)
                  end
                end
              else
                (rs.column_count - T.actual_table_field_count).times { |_| rs.read }
              end
            ensure
              rs.read_to_end
            end
          end
        end
        collection = h_result.values
        @relations.each do |rel|
          collection.each(&.relation_retrieved(rel))
        end
        add_preloaded(collection)
      end

      private def adapter
        T.adapter
      end
    end
  end
end
