require "../model/base"
require "set"

module Jennifer
  module QueryBuilder
    class RelationNestingTree(T)
      def clone
        clone = {{@type}}.allocate
        # clone.@attr = @attr
        clone
      end

      alias Element = Tuple(Int32, Relation::IRelation)

      getter bucket : Array(Element)

      def initialize
        @bucket = [] of Element
      end

      def add_relation(rel)
        @bucket << {0, T.relation(rel.to_s)}
      end

      def add_relation(query, rel, context = T, index : Int32 = 0)
        name = rel.to_s
        relation = context.relation(name)
        relation.join_condition(query, :left)
        @bucket << {index, relation}
      end

      def add_deep_relation(query, rel, nested_rel : Symbol, context = T, index : Int32 = 0)
        rel_name = rel.to_s
        existing_relation_index = @bucket.index { |pair| pair[0] == index && pair[1].name == rel_name }
        unless existing_relation_index
          add_relation(query, rel, context, index)
          existing_relation_index = @bucket.size - 1
        end

        existing_relation = @bucket[existing_relation_index][1]

        add_relation(query, nested_rel, existing_relation.model_class, existing_relation_index + 1)
      end

      def add_deep_relation(query, rel, nested_rels : Array, context = T, index : Int32 = 0)
        nested_rels.each { |nested_rel| add_deep_relation(query, rel, nested_rel, context, index) }
      end

      def add_deep_relation(query, rel, nested_rels : Hash | NamedTuple, context = T, index : Int32 = 0)
        rel_name = rel.to_s
        new_index = @bucket.index { |pair| pair[0] == index && pair[1].name == rel_name }
        if new_index
          new_index = new_index.not_nil!
        else
          add_relation(query, rel_name, context, index)
          new_index = @bucket.size
        end
        new_context = context.relation(rel.to_s).model_class
        nested_rels.each { |name, nested_rel| add_deep_relation(query, name, nested_rel, new_context, new_index) }
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

      def read(rs, h_result : Hash(DBAny, T))
        # h_result = {} of String => @class

        models = @bucket.map { |e| e[1].model_class }
        existence = @bucket.map { |_| {} of DBAny => Set(DBAny) }
        repo = @bucket.map { |_| {} of DBAny => Model::Resource }

        context = Array(Model::Resource?).new(@bucket.size + 1, nil)

        rs.each do
          begin
            h = build_hash(rs, T.actual_table_field_count)
            main_field = T.primary_field_name
            
            if h[main_field]?
              obj = (h_result[h[main_field]] ||= T.build(h, false).as(T))
              context[0] = obj
              models.each_with_index do |model, i|
                related_context_index = @bucket[i][0]
                relation = @bucket[i][1]
                related_context = context[related_context_index].not_nil!
                h = build_hash(rs, model.actual_table_field_count)
                pfn = model.primary_field_name
                if h[pfn].nil? 
                  context[i + 1] = nil
                elsif existence[i][h[pfn]]?.try(&.includes?(related_context.primary))
                  context[i + 1] = repo[i][h[pfn]]
                elsif repo[i][h[pfn]]?
                  (existence[i][h[pfn]] ||= Set(DBAny).new) << related_context.primary
                  context[i + 1] = (repo[i][h[pfn]] = related_context.append_relation(relation.name, repo[i][h[pfn]]).not_nil!)
                else
                  (existence[i][h[pfn]] ||= Set(DBAny).new) << related_context.primary
                  context[i + 1] = (repo[i][h[pfn]] = related_context.append_relation(relation.name, h).not_nil!)
                end
                # TODO: move this outside of retrieving objects
                related_context.relation_retrieved(relation.name) if related_context_index != 0
              end
            else
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
