require "./*"

module Jennifer
  module QueryBuilder
    class ModelQuery(T) < Query
      def model_class
        T
      end

      def table
        @table.empty? ? T.table_name : @table
      end

      def with(*arr)
        arr.map(&.to_s).to_a.each do |name|
          table_name = T.relation(name).table_name
          temp_joins = @joins.select { |j| j.table == table_name }
          join = temp_joins.find(&.relation.nil?)
          if join
            join.not_nil!.relation = name
          elsif temp_joins.size == 0
            raise BaseException.new("#with should be called after correspond join: no such table \"#{table_name}\" of relation \"#{name}\"")
          end
          @relations << name
        end
        self
      end

      def relation(name, type = :inner)
        T.relation(name.to_s).join_condition(self, type)
      end

      def includes(*names)
        names.each do |name|
          includes(name)
        end
        self
      end

      def includes(name : String | Symbol)
        @relations << name.to_s
        relation(name)
      end

      def includes(rels : Array(String), aliases = [] of String?)
        @relations << name.to_s
        raise "Not implemented"
      end

      def destroy
        to_a.each(&.destroy)
      end

      # TODO: debug case when exception was rised under #each
      def to_a
        add_aliases if @relation_used
        return to_a_with_relations if @relations.size > 0
        result = [] of T
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            result << T.build(rs)
          end
        end
        result
      end

      # ========= private ==============

      private def reverse_order
        if @order.empty?
          @order[T.primary_field_name] = "DESC"
        else
          super
        end
      end

      private def to_a_with_relations
        h_result = {} of String => T

        models = @relations.map { |e| T.relations[e].model_class }
        existence = @relations.map { |_| {} of String => Bool }
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            h = build_hash(rs, T.field_count)
            main_field = T.primary_field_name
            if h[main_field]?
              obj = (h_result[h[main_field].to_s] ||= T.build(h, false))
              models.each_with_index do |model, i|
                h = build_hash(rs, model.field_count)
                pfn = model.primary_field_name
                if h[pfn].nil? || existence[i][h[pfn].to_s]?
                  (rs.column_count - rs.column_index).times do |i|
                    rs.read
                  end
                  break
                else
                  existence[i][h[pfn].to_s] = true
                  obj.append_relation(@relations[i], h)
                end
              end
            else
              (rs.column_count - T.field_count).times { |_| rs.read }
            end
          end
        end
        h_result.values
      end

      private def add_aliases
        table_names = [table] + @joins.map { |e| e.table if !e.aliass }.compact
        duplicates = extract_duplicates(table_names)
        return if duplicates.empty?
        i = 0
        @table_aliases.clear
        @joins.each do |j|
          if j.relation && duplicates.includes?(j.table)
            @table_aliases[j.relation.as(String)] = "t#{i}"
            i += 1
          end
        end
        @joins.each { |j| j.alias_tables(@table_aliases) }
        @tree.not_nil!.alias_tables(@table_aliases) if @tree
      end

      private def build_hash(rs, size)
        h = {} of String => DBAny
        size.times do |i|
          h[rs.current_column_name] = rs.read(DBAny)
        end
        h
      end

      private def extract_duplicates(arr)
        result = [] of String
        entries = Hash(String, Int32).new(0)

        arr.each do |name|
          entries[name] += 1
        end
        result = [] of String
        entries.each { |k, v| result << k if v > 1 }
        result
      end
    end
  end
end
