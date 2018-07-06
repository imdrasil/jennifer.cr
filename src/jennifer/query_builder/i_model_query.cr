require "./query"
require "./eager_loading"

module Jennifer
  module QueryBuilder
    abstract class IModelQuery < Query
      include EagerLoading

      # NOTE: improperly detects source of #abstract_class if run sam with only Version model
      def model_class
        raise AbstractMethod.new(:model_class, {{@type}})
      end

      # NOTE: can't be abstract because is already implemented by super class
      def clone
        raise AbstractMethod.new(:clone, {{@type}})
      end

      # Returns target table name
      def table
        @table.empty? ? model_class.table_name : @table
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

      # Triggers `#destroy` on the each matched object
      def destroy
        find_each(&.destroy)
      end

      # Triggers `#update` on the each matched object
      def patch(options : Hash | NamedTuple)
        find_each(&.update(options))
      end

      def patch(**opts)
        patch(opts)
      end

      # Triggers `#update!` on the each matched object
      def patch!(options : Hash | NamedTuple)
        find_each(&.update!(options))
      end

      def patch!(**opts)
        patch!(opts)
      end

      # ========= private ==============

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
