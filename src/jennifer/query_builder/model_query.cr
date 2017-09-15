require "./*"

module Jennifer
  module QueryBuilder
    abstract class IModelQuery < Query
      abstract def model_class
      abstract def with(arr)
    end

    class ModelQuery(T) < IModelQuery
      @preload_relations = [] of String

      def initialize(*opts)
        super
      end

      def model_class
        T
      end

      def table
        @table.empty? ? T.table_name : @table
      end

      def with(*arr)
        self.with(arr.to_a.map(&.to_s))
      end

      def with(arr : Array)
        arr.each do |name|
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

      def preload(relation : Symbol | String)
        @preload_relations << relation.to_s
        self
      end

      def preload(relations : Array)
        relations.each { |rel| @preload_relations << rel.to_s }
        self
      end

      def preload(*relations)
        relations.each { |rel| @preload_relations << rel.to_s }
        self
      end

      def relation(name, type = :left)
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

      def to_a
        add_aliases if @relation_used
        return [] of T if @do_nothing
        return to_a_with_relations unless @relations.empty?
        result = [] of T
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            begin
              result << T.build(rs)
            ensure
              rs.read_to_end
            end
          end
        end
        add_preloaded(result)
      end

      # ========= private ==============

      private def reverse_order
        if @order.empty?
          # TODO: make smth like T.primary_field.to_s
          @order["#{T.table_name}.#{T.primary_field_name}"] = "DESC"
        else
          super
        end
      end

      # Loads relations added by `preload` method; makes one separate request per each relation
      private def add_preloaded(collection)
        return collection if collection.empty?
        primary_fields = [] of DBAny
        last_primary_field_name = ""

        @preload_relations.each do |name|
          rel = T.relation(name)
          _primary = rel.primary_field
          _foreign = rel.foreign_field

          if last_primary_field_name != _primary
            last_primary_field_name = _primary
            primary_fields.clear
            collection.each { |e| primary_fields << e.attribute(_primary) }
          end

          new_collection = rel.query(primary_fields).db_results

          unless new_collection.empty?
            collection.each_with_index do |mod, i|
              pv = primary_fields[i]
              # TODO: check if deleting elements from array will increase performance
              new_collection.each { |hash| mod.append_relation(name, hash) if hash[_foreign] == pv }
            end
          end
        end
        collection
      end

      # TODO: brake this method to smaller ones
      private def to_a_with_relations
        h_result = {} of String => T

        models = @relations.map { |e| T.relations[e].model_class }
        existence = @relations.map { |_| {} of String => Bool }
        ::Jennifer::Adapter.adapter.select(self) do |rs|
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
                    obj.append_relation(@relations[i], h)
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
        add_preloaded(h_result.values)
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
