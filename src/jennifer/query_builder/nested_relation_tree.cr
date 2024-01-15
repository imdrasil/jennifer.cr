require "./relation_tree"

module Jennifer
  module QueryBuilder
    # Wrapper class to store information what model relations structure should be loaded in a request.
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
        models = bucket.map(&.[1].model_class)
        # Found relation primary keys for i-th relation primary key
        existence = bucket.map { {} of DBAny => Set(DBAny) }
        # All found relation records for i-th relation
        repo = bucket.map { {} of DBAny => Model::Resource }
        # Stack of relation assignment
        stack = Array(Model::Resource?).new(bucket.size + 1, nil)

        rs.each do
          begin
            column_index = T.actual_table_field_count
            current_attributes = build_hash(rs, 0, T.actual_table_field_count)
            pfn = T.primary_field_name
            pfv = current_attributes[pfn]?
            next unless pfv

            # Row has primary field -> it is not empty
            stack[0] = h_result[pfv] ||= T.new(current_attributes, false).as(T)
            models.each_with_index do |model, i|
              read_relation(rs, model, i, stack, column_index, existence, repo)
              column_index += model.actual_table_field_count
            end
          ensure
            rs.read_to_end
          end
        end

        collection = h_result.values

        bucket.each do |pair|
          next unless pair[0] == 0

          collection.each(&.relation_retrieved(pair[1].name))
        end
        collection
      end

      private def read_relation(rs, model, i, stack, column_index, existence, repo)
        related_context_index, relation = bucket[i]
        related_context = stack[related_context_index]
        # Parent record is missing -> skip current relation
        return stack[i + 1] = nil if related_context.nil?

        current_attributes = build_hash(rs, column_index, model.actual_table_field_count)
        pfn = model.primary_field_name
        pfv = current_attributes[pfn]

        if pfv.nil?
          # Row has empty primary field or parent record is missing -> empty record
          stack[i + 1] = nil
        elsif !repo[i].has_key?(pfv)
          # New record -> add to the collection and change context
          existence[i][pfv] = Set(DBAny){related_context.primary}
          stack[i + 1] =
            repo[i][pfv] =
              related_context.append_relation(relation.name, current_attributes)
        elsif existence[i][pfv]?.try(&.includes?(related_context.primary))
          # Such primary key has been already retrieved for current context -> change context and do nothing
          stack[i + 1] = repo[i][pfv]
        else
          # Such primary key has been already retrieved for current context -> use it and change context
          existence[i][pfv] << related_context.primary
          stack[i + 1] = related_context.append_relation(relation.name, repo[i][pfv])
        end
        # TODO: move this outside of retrieving objects
        # Mark relation as retrieved one
        related_context.relation_retrieved(relation.name) if related_context_index != 0
      end

      private def build_hash(rs, start_index, size)
        hash = {} of String => DBAny
        size.times do |index_shift|
          column = rs.columns[start_index + index_shift]
          hash[column.name] = adapter.read_column(rs, column)
        end
        hash
      end
    end
  end
end
