require "./relation_tree"

module Jennifer
  module QueryBuilder
    # Wrapper class to store information what model relations structure should be loaded in the separate requests.
    class MultiQueryRelationTree < RelationTree
      def add_relation(query, rel, context = @klass, index : Int32 = 0)
        name = rel.to_s
        relation = context.relation(name)
        @bucket << {index, relation}
      end

      def preload(collection)
        repo = Array(Array(Model::Resource)).new(@bucket.size + 1)
        (@bucket.size + 1).times { repo << [] of Model::Resource }
        collection.each { |record| repo[0] << record }

        pk_repo = Array(Hash(DBAny, Array(DBAny))).new(@bucket.size + 1)
        (@bucket.size + 1).times { pk_repo << {} of DBAny => Array(DBAny) }

        @bucket.each_with_index do |pair, index|
          pair[1].preload_relation(repo[pair[0]], repo[index + 1].as(Array(Model::Resource)), pk_repo[index])
        end
      end
    end
  end
end
