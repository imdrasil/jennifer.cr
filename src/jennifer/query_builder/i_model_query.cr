require "./query"
require "./eager_loading"

module Jennifer
  module QueryBuilder
    abstract class IModelQuery < Query
      include EagerLoading

      private delegate :write_adapter, :read_adapter, to: model_class

      # NOTE: improperly detects source of #abstract_class if run Sam with only Version model
      def model_class
        raise AbstractMethod.new(:model_class, {{@type}})
      end

      # NOTE: can't be abstract because is already implemented by super class.
      def clone
        raise AbstractMethod.new(:clone, {{@type}})
      end

      # Returns target table name.
      def table
        @table.empty? ? model_class.table_name : @table
      end

      # Joins *name* relation.
      #
      # You can specify join type passing it as 2nd argument.
      #
      # ```
      # Contact.all.relation(:addresses)
      # ```
      def relation(name, type = :left)
        model_class.relation(name.to_s).join_condition(self, type)
      end

      # Returns record by given primary field or `nil` otherwise.
      #
      # ```
      # Contact.all.find(-1) # => nil
      # ```
      def find(id)
        this = self
        where { this.model_class.primary == id }.first
      end

      # Returns record by given primary field or raises `Jennifer::RecordNotFound` exception otherwise.
      #
      # ```
      # Contact.all.find!(-1) # Jennifer::RecordNotFound
      # ```
      def find!(id)
        this = self
        where { this.model_class.primary == id }.first!
      end

      # Yields each batch of records that was found by the specified query.
      #
      # ```
      # Contact.all.where { _age > 21 }.find_in_batches do |batch|
      #   batch.each do |contact|
      #     puts contact.id
      #   end
      # end
      # ```
      #
      # To get each record one by one use #find_each instead.
      #
      # NOTE: any given ordering will be ignored and query will be reordered based on the
      # *primary_key* and *direction*.
      def find_in_batches(batch_size : Int32 = 1000, start = nil, direction : String | Symbol = "asc", &)
        super(model_class.primary, batch_size, start, direction) { |records| yield records }
      end

      # Yields each record in batches from #find_in_batches.
      #
      # Looping through a collection of records from the database is very inefficient since it will instantiate all the objects
      # at once. In that case batch processing methods allow you to work with the records
      # in batches, thereby greatly reducing memory consumption.
      #
      # ```
      # Contact.all.where { _age > 21 }.find_each do |contact|
      #   puts contact.id
      # end
      # ```
      def find_each(batch_size : Int32 = 1000, start = nil, direction : String | Symbol = "asc", &)
        super(model_class.primary, batch_size, start, direction) { |record| yield record }
      end

      # Triggers `#destroy` on the each matched object.
      #
      # ```
      # Contact.all.where { _name.like('%John%') }.destroy
      # ```
      def destroy
        find_each(&.destroy)
      end

      # Triggers `#update` on the each matched object.
      #
      # As a result all callbacks and validations are invoked.
      #
      # ```
      # Contact.all.where { _name == "Ohn" }.patch({name: "John"})
      # ```
      def patch(options : Hash | NamedTuple)
        find_each(&.update(options))
      end

      # :ditto:
      def patch(**opts)
        patch(opts)
      end

      # Triggers `#update!` on the each matched object.
      #
      # As a result all callbacks and validations are invoked. If any individual update raise exception -
      # it will stop all following operations.
      #
      # ```
      # Contact.all.where { _name == "Ohn" }.patch!({name: "John"})
      # ```
      def patch!(options : Hash | NamedTuple)
        find_each(&.update!(options))
      end

      # :ditto:
      def patch!(**opts)
        patch!(opts)
      end

      # ========= private ==============

      private def adapter
        model_class.adapter
      end

      private def add_aliases
        table_names = [table]
        table_names.concat(_joins!.compact_map { |e| e.table unless e.has_alias? }) if _joins?
        duplicates = extract_duplicates(table_names)
        return if duplicates.empty?

        i = 0
        @table_aliases.clear
        if _joins?
          _joins!.each do |j|
            if j.relation && duplicates.includes?(j.table)
              @table_aliases[j.relation.as(String)] = "t#{i}"
              i += 1
            end
          end
          _joins!.each(&.alias_tables(@table_aliases))
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
