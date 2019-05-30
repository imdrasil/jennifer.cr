module Jennifer
  module QueryBuilder
    module Executables
      # Returns last matched record or `nil`.
      #
      # Doesn't affect query instance.
      def last
        reverse_order
        old_limit = @limit
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        reverse_order
        r
      end

      # Returns last matched record or raise `RecordNotFound` exception otherwise.
      #
      # Doesn't affect query instance.
      def last!
        old_limit = @limit
        @limit = 1
        reverse_order
        result = to_a
        reverse_order
        @limit = old_limit
        raise RecordNotFound.from_query(self, adapter) if result.empty?
        result[0]
      end

      # Returns first matched record or `nil`.
      #
      # Doesn't affect query instance.
      def first
        old_limit = @limit
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        r
      end

      # Returns first matched record or raise `RecordNotFound` exception otherwise.
      #
      # Doesn't affect query instance.
      def first!
        old_limit = @limit
        result = to_a
        @limit = old_limit
        raise RecordNotFound.from_query(self, adapter) if result.empty?
        result[0]
      end

      # Returns array of given field values.
      #
      # This method allows you load only those fields you need without loading records.
      # If query is ModelQuery - take into consideration that fields will not be converted by
      # model converters.
      def pluck(fields : Array) : Array(Array(DBAny))
        return [] of Array(DBAny) if do_nothing?
        adapter.pluck(self, fields.map(&.to_s))
      end

      # ditto
      def pluck(*fields : String | Symbol)
        pluck(fields.to_a)
      end

      def pluck(field : String | Symbol) : Array(DBAny)
        return [] of DBAny if do_nothing?
        adapter.pluck(self, field.to_s)
      end

      # Delete all records which satisfy given conditions.
      #
      # No callbacks or validation will be executed.
      def delete
        return if do_nothing?
        adapter.delete(self)
      end

      # Returns whether any record satisfying given conditions exists.
      def exists? : Bool
        return false if do_nothing?
        adapter.exists?(self)
      end

      # Updates specified fields by given value retrieved from the block.
      #
      # Expects block to return `Hash(Symbol, DBAny | Jennifer::QueryBuilder::Statement)`.
      #
      # ```
      # Contact.all.where { and(_name == "Jon", age > 100) }.update { { :name => "John", :age => _age - 15 } }
      # ```
      def update
        definition = (with @expression yield)
        return DB::ExecResult.new(0i64, 0i64) if do_nothing?
        adapter.modify(self, definition)
      end

      def update(options : Hash)
        return DB::ExecResult.new(0i64, 0i64) if do_nothing?
        adapter.update(self, options)
      end

      def update(**options)
        update(options.to_h)
      end

      # Increments specified fields by given value.
      #
      # ```
      # Contact.all.increment({ :likes => 1 })
      # ```
      #
      # No validation or callback is invoked.
      def increment(fields : Hash(Symbol, _))
        hash = {} of Symbol => Condition
        update do
          fields.each { |field, value| hash[field] = c(field.to_s) + value.as(DBAny) }
          hash
        end
      end

      # Increments specified fields by given value.
      #
      # ```
      # Contact.all.increment(likes: 1)
      # ```
      #
      # No validation or callback is invoked.
      def increment(**fields)
        increment(fields.to_h)
      end

      # Decrements specified fields by given value.
      #
      # For more details take a look at #increment.
      def decrement(fields : Hash(Symbol, _))
        hash = {} of Symbol => Condition
        update do
          fields.each { |field, value| hash[field] = c(field.to_s) - value.as(DBAny) }
          hash
        end
      end

      # ditto
      def decrement(**fields)
        decrement(fields.to_h)
      end

      def to_a
        results
      end

      def db_results
        result = [] of Hash(String, DBAny)
        each_result_set do |rs|
          result << adapter.result_to_hash(rs)
        end
        result
      end

      def results
        result = [] of Record
        each_result_set { |rs| result << Record.new(rs) }
        result
      end

      # Returns array of record ids.
      #
      # This method requires model to have field `id : Int32`.
      def ids
        pluck(:id).map(&.as(Int32))
      end

      # Yields each matched record to a block.
      #
      # To iterate over records they are loaded from the DB so this may effect memory usage.
      # Prefer #find_each.
      def each
        to_a.each do |e|
          yield e
        end
      end

      # Yields each result set object to a block.
      def each_result_set(&block)
        return if do_nothing?
        adapter.select(self) do |rs|
          begin
            rs.each do
              yield rs
            end
          rescue e : Exception
            rs.read_to_end
            raise e
          end
        end
      end

      # Yields each batch of records that was found by the specified query.
      #
      # ```
      # Jennifer::Query["contacts"].where { _age > 21 }.find_in_batches("id") do |batch|
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
      def find_in_batches(primary_key : String, batch_size : Int32 = 1000, start : Int32? = nil, direction : String | Symbol = "asc", &block)
        find_in_batches(@expression.c(primary_key.not_nil!), batch_size, start, direction) { |records| yield records }
      end

      def find_in_batches(batch_size : Int32 = 1000, start : Int32 = 0, &block)
        find_in_batches(nil, batch_size, start) { |records| yield records }
      end

      def find_in_batches(primary_key : Criteria, batch_size : Int32 = 1000, start = nil, direction : String | Symbol = "asc", &block)
        Config.logger.warn("#find_in_batches is invoked with already ordered query - it will be reordered") if ordered?
        request = clone.reorder(primary_key.order(direction)).limit(batch_size)

        records = start ? request.clone.where { primary_key >= start }.to_a : request.to_a
        while records.any?
          records_size = records.size
          primary_key_offset = records.last.attribute(primary_key.field)
          yield records
          break if records_size < batch_size
          records = request.clone.where { primary_key > primary_key_offset }.to_a
        end
      end

      def find_in_batches(primary_key : Nil, batch_size : Int32 = 1000, start : Int32 = 0, &block)
        Config.logger.warn("#find_in_batches is invoked with already ordered query - it will be reordered") if ordered?
        Config.logger.warn("#find_in_batches methods was invoked without passing primary_key" \
                          " key field name which may results in incorrect records extraction; 'start' argument" \
                          " was realized as page number.")
        request = clone.reorder.limit(batch_size)

        records = request.offset(start * batch_size).to_a
        while records.any?
          records_size = records.size
          yield records
          break if records_size < batch_size
          start += 1
          records = request.offset(start * batch_size).to_a
        end
      end

      # Yields each record in batches from #find_in_batches.
      #
      # Looping through a collection of records from the database is very inefficient since it will instantiate all the objects
      # at once. In that case batch processing methods allow you to work with the records
      # in batches, thereby greatly reducing memory consumption.
      #
      # ```
      # Jennifer::Query["contacts"].where { _age > 21 }.find_each("id") do |contact|
      #   puts contact.id
      # end
      # ```
      def find_each(primary_key : String, batch_size : Int32 = 1000, start = nil, direction : String | Symbol = "asc", &block)
        find_in_batches(primary_key, batch_size, start, direction) do |records|
          records.each { |rec| yield rec }
        end
      end

      def find_each(primary_key : Criteria, batch_size : Int32 = 1000, start = nil, direction : String | Symbol = "asc", &block)
        find_in_batches(primary_key, batch_size, start, direction) do |records|
          records.each { |rec| yield rec }
        end
      end

      def find_each(primary_key : Nil, batch_size : Int32 = 1000, start : Int32 = 0, direction : String | Symbol = "asc", &block)
        find_in_batches(batch_size, start) do |records|
          records.each { |rec| yield rec }
        end
      end

      def find_each(batch_size : Int32 = 1000, start : Int32 = 0, direction : String | Symbol = "asc", &block)
        find_in_batches(batch_size, start) do |records|
          records.each { |rec| yield rec }
        end
      end

      # Executes a custom SQL query against DB and returns array of `Record`.
      #
      # Any query conditions specified earlier are ignored.
      #
      # ```
      # query = "SELECT name FROM users WHERE age > %1"
      # Jennifer::Query["contacts"].find_records_by_sql(query, [21]) # [<Record: name="Roland">]
      # ```
      def find_records_by_sql(query : String, args : Array(DBAny) = [] of DBAny)
        results = [] of Record
        return results if do_nothing?
        adapter.query(query, args) do |rs|
          begin
            rs.each do
              results << Record.new(rs)
            end
          rescue e : Exception
            rs.read_to_end
            raise e
          end
        end
        results
      end
    end
  end
end
