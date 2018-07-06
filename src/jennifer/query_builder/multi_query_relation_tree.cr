require "./relation_tree"

module Jennifer
  module QueryBuilder
    class MultiQueryRelationTree < RelationTree
      def add_relation(query, rel, context = @klass, index : Int32 = 0)
        name = rel.to_s
        relation = context.relation(name)
        @bucket << {index, relation}
      end

      def preload(collection)
        primary_fields = [] of DBAny
        last_primary_field_name = ""
        repo = Array(Array(Model::Resource)).new(@bucket.size + 1)
        (@bucket.size + 1).times { |_| repo << [] of Model::Resource }
        collection.each { |c| repo[0] << c }

        pk_repo = Array(Hash(DBAny, Array(DBAny))).new(@bucket.size + 1)
        (@bucket.size + 1).times { |_| pk_repo << {} of DBAny => Array(DBAny) }

        @bucket.each_with_index do |pair, index|
          pair[1].preload_relation(repo[pair[0]], repo[index + 1].as(Array(Model::Resource)), pk_repo[index])
        end
      end
    end
  end
end
