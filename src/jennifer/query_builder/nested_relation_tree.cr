require "./relation_tree"

module Jennifer
  module QueryBuilder
    class NestedRelationTree < RelationTree
      def add_relation(query, rel, context = @klass, index : Int32 = 0)
        name = rel.to_s
        relation = context.relation(name)
        relation.join_condition(query, :left)
        @bucket << {index, relation}
      end

      def select_fields(query)
        eb = query.expression_builder
        buff = Array(Criteria).new(@bucket.size + 1)
        buff << eb.star

        @bucket.each do |pair|
          rel = pair[1]
          table_name = query._table_aliases[rel.name]? || rel.table_name
          buff << eb.star(table_name)
        end
        buff
      end

      def read(rs, klass : T.class) forall T
        h_result = {} of DBAny => T

        # All relations model classes
        models = @bucket.map { |e| e[1].model_class }
        # Represents found relation primary keys for i-th relation primary key
        existence = @bucket.map { |_| {} of DBAny => Set(DBAny) }
        # Stores all found relation records for i-th relation
        repo = @bucket.map { |_| {} of DBAny => Model::Resource }
        # Stores context of relation assignment; works similar to callstack
        context = Array(Model::Resource?).new(@bucket.size + 1, nil)

        rs.each do
          begin
            h = build_hash(rs, T.actual_table_field_count)
            main_field = T.primary_field_name

            if h[main_field]?
              # Row has primary field -> it is not empty
              obj = (h_result[h[main_field]] ||= T.build(h, false).as(T))
              context[0] = obj
              models.each_with_index do |model, i|
                related_context_index = @bucket[i][0]
                related_context = context[related_context_index].not_nil!
                relation = @bucket[i][1]
                h = build_hash(rs, model.actual_table_field_count)
                pfn = model.primary_field_name
                if h[pfn].nil?
                  # Row has empty primary field -> empty record
                  context[i + 1] = nil
                elsif existence[i][h[pfn]]?.try(&.includes?(related_context.primary))
                  # Such primary key has been already retrieved for current context -> change context and do nothing
                  context[i + 1] = repo[i][h[pfn]]
                elsif repo[i][h[pfn]]?
                  # Such primary key has been already retrieved for current context -> use it and change context
                  (existence[i][h[pfn]] ||= Set(DBAny).new) << related_context.primary
                  context[i + 1] = (repo[i][h[pfn]] = related_context.append_relation(relation.name, repo[i][h[pfn]]).not_nil!)
                else
                  # New record -> add to the collection and change context
                  (existence[i][h[pfn]] ||= Set(DBAny).new) << related_context.primary
                  context[i + 1] = (repo[i][h[pfn]] = related_context.append_relation(relation.name, h).not_nil!)
                end
                # TODO: move this outside of retrieving objects
                # Mark relation as retrieved one
                related_context.relation_retrieved(relation.name) if related_context_index != 0
              end
            else
              # Primary field nil -> read to the end
              (rs.column_count - T.actual_table_field_count).times { |_| rs.read }
            end
          ensure
            rs.read_to_end
          end
        end

        collection = h_result.values

        @bucket.each do |pair|
          next if pair[0] != 0
          collection.each(&.relation_retrieved(pair[1].name))
        end
        collection
      end

      private def build_hash(rs, size)
        h = {} of String => DBAny
        size.times do |i|
          h[rs.current_column_name] = rs.read(DBAny)
        end
        h
      end
    end
  end
end
