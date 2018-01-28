require "./query"

module Jennifer
  module QueryBuilder
    abstract class IModelQuery < Query
      @preload_relations = [] of String

      # NOTE: improperly detects source of #abstract_class if run sam with only Version model
      def model_class
        raise AbstractMethod.new(:model_class, {{@type}})
      end

      # NOTE: can't be abstract because is already implemented by super class
      def clone
        raise AbstractMethod.new(:clone, {{@type}})
      end

      protected def preload_relations
        @preload_relations
      end

      # Returns target table name
      def table
        @table.empty? ? model_class.table_name : @table
      end

      def _select_fields : Array(Criteria)
        if @select_fields.empty?
          buff = [] of Criteria
          buff << @expression.star
          if !@relations.empty?
            @relations.each do |r|
              table_name = @table_aliases[r]? || model_class.relation(r).table_name
              buff << @expression.star(table_name)
            end
          end
          buff
        else
          @select_fields
        end
      end

      def with(*arr)
        self.with(arr.to_a.map(&.to_s))
      end

      def with(arr : Array)
        arr.each do |name|
          table_name = model_class.relation(name).table_name
          if @joins
            temp_joins = _joins!.select { |j| j.table == table_name }
            join = temp_joins.find(&.relation.nil?)
            if join
              join.not_nil!.relation = name
            elsif temp_joins.size == 0
              raise BaseException.new("#with should be called after correspond join: no such table \"#{table_name}\" of relation \"#{name}\"")
            end
          else
            raise BaseException.new("#with should be called after correspond join: no such table \"#{table_name}\" of relation \"#{name}\"")
          end
          @relations << name
        end
        self
      end

      # Preload given relation after object loading
      def includes(relation : Symbol | String)
        @preload_relations << relation.to_s
        self
      end

      # Preload given relations after object loading
      def includes(relations : Array)
        relations.each { |rel| @preload_relations << rel.to_s }
        self
      end

      # Preload given relations after object loading
      def includes(*relations)
        relations.each { |rel| @preload_relations << rel.to_s }
        self
      end

      # Alias for includes
      def preload(relation)
        includes(relation)
      end

      # Alias for includes
      def preload(*relations)
        includes(relations)
      end

      # Adds to select statement given relations (with correspond joins) and loads them from result
      def eager_load(*names)
        names.each { |name| eager_load(name) }
        self
      end

      # Adds to select statement given relation (with correspond joins) and loads them from result
      def eager_load(name : String | Symbol)
        @relations << name.to_s
        relation(name)
      end

      # NOTE: Not implemented yet
      def eager_load(rels : Array(String), aliases = [] of String?)
        @relations << name.to_s
        raise "Not implemented"
      end

      def relation(name, type = :left)
        model_class.relation(name.to_s).join_condition(self, type)
      end

      def find_in_batches(batch_size : Int32 = 1000, start = nil, direction : String | Symbol = "asc", &block)
        super(model_class.primary, batch_size, start, direction) { |records| yield records }
      end

      def find_each(batch_size : Int32 = 1000, start = nil, direction : String | Symbol = "asc", &block)
        super(model_class.primary, batch_size, start, direction) { |record| yield record }
      end

      # Loads all records and call `#destroy` on the each
      def destroy
        to_a.each(&.destroy)
      end

      # ========= private ==============

      # Loads relations added by `preload` method; makes one separate request per each relation
      private def add_preloaded(collection)
        return collection if collection.empty?
        primary_fields = [] of DBAny
        last_primary_field_name = ""

        @preload_relations.each do |name|
          rel = model_class.relation(name)
          _primary = rel.primary_field
          _foreign = rel.foreign_field

          if last_primary_field_name != _primary
            last_primary_field_name = _primary
            primary_fields.clear
            collection.each { |e| primary_fields << e.attribute(_primary) }
          end

          new_collection = rel.query(primary_fields).db_results

          if new_collection.empty?
            collection.each(&.relation_retrieved(name))
          else
            collection.each_with_index do |mod, i|
              pv = primary_fields[i]
              # TODO: check if deleting elements from array will increase performance
              new_collection.each { |hash| mod.append_relation(name, hash) if hash[_foreign] == pv }
            end
          end
        end
        collection
      end

      private def add_aliases
        table_names = [table]
        table_names.concat(_joins!.map { |e| e.table unless e.has_alias? }.compact) if @joins
        duplicates = extract_duplicates(table_names)
        return if duplicates.empty?
        i = 0
        @table_aliases.clear
        if @joins
          _joins!.each do |j|
            if j.relation && duplicates.includes?(j.table)
              @table_aliases[j.relation.as(String)] = "t#{i}"
              i += 1
            end
          end
          _joins!.each { |j| j.alias_tables(@table_aliases) }
        end
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
        entries.each { |k, v| result << k if v > 1 }
        result
      end
    end
  end
end
