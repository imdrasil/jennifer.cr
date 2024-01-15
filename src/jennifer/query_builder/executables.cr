module Jennifer
  module QueryBuilder
    # All query methods that invokes database query.
    #
    # A lot of methods in this module accepts strings and symbols. Any string is
    # considered as a plain SQL and is inserted as-is; any symbol - as a current table field.
    module Executables
      # Returns last matched record or `nil`.
      #
      # Doesn't modify query instance.
      #
      # ```
      # Contact.where { _city_id == 3 }.last
      # ```
      def last
        old_limit = @limit
        old_order = @order
        reverse_order
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        @order = old_order
        r
      end

      # Returns last matched record or raise `RecordNotFound` exception otherwise.
      #
      # Doesn't modify query instance.
      #
      # ```
      # Contact.where { _city_id == 3 }.last!
      # ```
      def last!
        result = last
        raise RecordNotFound.from_query(self, adapter) if result.nil?

        result
      end

      # Returns first matched record or `nil`.
      #
      # Doesn't modify query instance.
      #
      # ```
      # Contact.where { _city_id == 3 }.first
      # ```
      def first
        old_limit = @limit
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        r
      end

      # Returns first matched record or raise `RecordNotFound` exception otherwise.
      #
      # Doesn't modify query instance.
      #
      # ```
      # Contact.where { _city_id == 3 }.first!
      # ```
      def first!
        result = first
        raise RecordNotFound.from_query(self, adapter) if result.nil?

        result
      end

      # Finds the first record matching the specified conditions.
      #
      # If no record is found, returns `nil`.
      #
      # ```
      # Jennifer::Query["contacts"].find_by({:id => -1}) # => nil
      # Jennifer::Query["contacts"].find_by({:id => 1})  # => Jennifer::Record
      # ```
      def find_by(conditions : Hash(Symbol | String, _))
        where(conditions).first
      end

      # Like `#find_by`, except that if no record is found, raises an `Jennifer::RecordNotFound` error.
      #
      # ```
      # Jennifer::Query["contacts"].find_by!({:id => -1}) # Jennifer::RecordNotFound
      # Jennifer::Query["contacts"].find_by!({:id => 1})  # => Jennifer::Record
      # ```
      def find_by!(conditions : Hash(Symbol | String, _))
        where(conditions).first!
      end

      # Returns array of given field values.
      #
      # This method allows you load only those fields you need without loading records.
      # If query is ModelQuery - take into consideration that fields will not be converted by
      # model converters.
      #
      # ```
      # Contact.all.limit(2).pluck([:id, :name]) # [[1, "Name 1"], [2, "Name 2"]]
      # ```
      def pluck(fields : Array) : Array(Array(DBAny))
        return [] of Array(DBAny) if do_nothing?

        read_adapter.pluck(self, fields.map(&.to_s))
      end

      def pluck(*fields : String | Symbol) : Array(Array(DBAny))
        pluck(fields.to_a)
      end

      def pluck(field : String | Symbol) : Array(DBAny)
        return [] of DBAny if do_nothing?

        read_adapter.pluck(self, field.to_s)
      end

      def pluck(**types : **T) forall T
        {% begin %}
          if do_nothing?
            return [] of {
              {% for name, type in T %}
                {{name}}: {{type.instance}},
              {% end %}
            }
          end

          read_adapter.pluck(self, types.keys.to_a.map(&.to_s)).map do |record|
            {
              {% index = -1 %}
              {% for name, type in T %}
                {{name}}: record[{{index += 1}}].as({{type.instance}}),
              {% end %}
            }
          end
        {% end %}
      end

      # Delete all records which satisfy given conditions.
      #
      # No model callbacks or validation will be executed.
      #
      # ```
      # Jennifer::Query["contacts"].where { _name.like("%dan%") }.delete
      # ```
      def delete
        return if do_nothing?

        write_adapter.delete(self)
      end

      # Returns whether any record satisfying given conditions exists.
      #
      # ```
      # Jennifer::Query["contacts"].where { _name.like("%dan%") }.exists?
      # ```
      def exists? : Bool
        return false if do_nothing?

        read_adapter.exists?(self)
      end

      # Creates new record in a database with given *fields* and *values*.
      #
      # Ignores any model callbacks.
      #
      # ```
      # Jennifer::Query["contacts"].insert(%w(name age), [["John", 60], ["Chris", 40]])
      # ```
      def insert(fields : Array(String), values : Array(Array(DBAny)))
        return if do_nothing? || values.empty?

        unless values.is_a?(Array(Array(DBAny)))
          values = values.map { |row| Ifrit.typed_array_cast(row, DBAny) }
        end
        write_adapter.bulk_insert(table, fields, values)
      end

      # Creates new record in a database with given *options*.
      #
      # Ignores any model callbacks.
      #
      # ```
      # Jennifer::Query["contacts"].insert({name: "John", age: 60})
      # ```
      def insert(options : Hash(String | Symbol, DBAny) | NamedTuple)
        return if do_nothing? || options.empty?

        fields = options.keys.to_a.map(&.to_s)
        values = Ifrit.typed_array_cast(options.values, DBAny)
        insert(fields, [values])
      end

      # Inserts given *values* and ignores ones that would cause a duplicate values of `UNIQUE` index on given
      # *unique_fields*.
      #
      # Some RDBMS (like MySQL) doesn't require specifying exact constraint to be violated, therefore *unique_fields*
      # argument by default
      # is `[] of String`.
      #
      # ```
      # Jennifer::Query["orders"].insert({:name => "Order 1", :uid => 123})
      # # the first record will be skipped
      # Jennifer::Query["orders"].upsert(%w(name uid), [["Order 1", 123], ["Order 2", 321]], %w(uid))
      # ```
      def upsert(fields : Array(String), values : Array(Array(DBAny)), unique_fields : Array = [] of String)
        return if do_nothing? || values.empty?

        write_adapter.upsert(table, fields, values, unique_fields, {} of String => String)
      end

      # Inserts given *values* modifies existing row using hash returned by the block.
      #
      # Some RDBMS (like MySQL) doesn't require specifying exact constraint to be violated, therefore *unique_fields*
      # argument by default
      # is `[] of String`.
      #
      # ```
      # Jennifer::Query["orders"].insert({:name => "Order 1", :uid => 123, :value => 2})
      # # the first record will be skipped
      # Jennifer::Query["orders"].upsert(%w(name uid value), [["Order 1", 123, 3], ["Order 2", 321, 4]], %w(uid)) do
      #   {:value => values(:value) + _value}
      # end
      # ```
      def upsert(fields : Array(String), values : Array(Array(DBAny)), unique_fields : Array, &)
        return if do_nothing? || values.empty?

        definition = (with @expression yield @expression)
        write_adapter.upsert(table, fields, values, unique_fields, definition)
      end

      # Updates specified fields by given value retrieved from the block.
      #
      # Expects block to return `Hash(Symbol, DBAny | Jennifer::QueryBuilder::Statement)`.
      #
      # ```
      # Contact.all.where { and(_name == "Jon", age > 100) }.update { {:name => "John", :age => _age - 15} }
      # ```
      def update(&)
        definition = (with @expression yield)
        return DB::ExecResult.new(0i64, 0i64) if do_nothing?

        write_adapter.modify(self, definition)
      end

      # Updates records with given *options*.
      #
      # ```
      # Contact.all.where { and(_name == "Jon", age > 100) }.update({:name => "John", :age => 40})
      # ```
      def update(options : Hash)
        return DB::ExecResult.new(0i64, 0i64) if do_nothing?

        write_adapter.update(self, options)
      end

      # Updates records with given *options*.
      #
      # ```
      # Contact.all.where { and(_name == "Jon", age > 100) }.update(name: "John", age: 40)
      # ```
      def update(**options)
        update(options.to_h)
      end

      # Increments specified fields by given value.
      #
      # ```
      # Contact.all.increment({:likes => 1})
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

      # :ditto:
      def decrement(**fields)
        decrement(fields.to_h)
      end

      # Alias for `#results`.
      def to_a
        results
      end

      # Returns array of hashes representing result sets.
      #
      # ```
      # Jennifer::Query["contacts"].where { _id == 1 }.db_results # => [{"id" => 1, "name" => "Name", ...}]
      # ```
      def db_results : Array(Hash(String, DBAny))
        result = [] of Hash(String, DBAny)
        each_result_set do |rs|
          result << read_adapter.result_to_hash(rs)
        end
        result
      end

      # Returns array of `Record` created based on result sets.
      #
      # ```
      # Jennifer::Query["contacts"].where { _id == 1 }.results
      # # => [Jennifer::Record(@attributes={"id" => 1, "name" => "Name", ...})]
      # ```
      def results : Array(Record)
        result = [] of Record
        each_result_set { |rs| result << Record.new(read_adapter.result_to_hash(rs)) }
        result
      end

      # Returns array of record ids.
      #
      # This method requires model to have field named `id` with type `Int64`.
      def ids
        pluck(:id).map(&.as(Int64))
      end

      # Yields each matched record to a block.
      #
      # To iterate over records they are loaded from the DB so this may effect memory usage.
      # Prefer #find_each.
      def each(&)
        to_a.each { |e| yield e }
      end

      # Yields each result set object to a block.
      def each_result_set(&)
        return if do_nothing?

        read_adapter.select(self) do |rs|
          begin
            rs.each { yield rs }
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
      def find_in_batches(primary_key : String, batch_size : Int32 = 1000, start : Int32? = nil,
                          direction : String | Symbol = "asc", &)
        find_in_batches(@expression.c(primary_key.not_nil!), batch_size, start, direction) { |records| yield records }
      end

      def find_in_batches(batch_size : Int32 = 1000, start : Int32 = 0, &)
        find_in_batches(nil, batch_size, start) { |records| yield records }
      end

      def find_in_batches(primary_key : Criteria, batch_size : Int32 = 1000, start = nil,
                          direction : String | Symbol = "asc", &)
        if ordered?
          Config.logger.warn { "#find_in_batches is invoked with already ordered query - it will be reordered" }
        end
        request = clone.reorder(primary_key.order(direction)).limit(batch_size)
        records = start ? request.clone.where { primary_key >= start }.to_a : request.to_a

        while !records.empty?
          records_size = records.size
          primary_key_offset = records.last.attribute(primary_key.field)
          yield records
          break if records_size < batch_size

          records = request.clone.where { primary_key > primary_key_offset }.to_a
        end
      end

      def find_in_batches(primary_key : Nil, batch_size : Int32 = 1000, start : Int32 = 0, &)
        if ordered?
          Config.logger.warn { "#find_in_batches is invoked with already ordered query - it will be reordered" }
        end
        Config.logger.warn do
          "#find_in_batches methods was invoked without passing primary_key key field name which may results in " \
          "incorrect records extraction; 'start' argument was realized as page number."
        end
        request = clone.reorder.limit(batch_size)

        records = request.offset(start.to_i64 * batch_size.to_i64).to_a
        while !records.empty?
          records_size = records.size
          yield records
          break if records_size < batch_size
          start += 1
          records = request.offset(start.to_i64 * batch_size.to_i64).to_a
        end
      end

      # Yields each record in batches from #find_in_batches.
      #
      # Looping through a collection of records from the database is very inefficient since it will instantiate all the
      # objects
      # at once. In that case batch processing methods allow you to work with the records
      # in batches, thereby greatly reducing memory consumption.
      #
      # ```
      # Jennifer::Query["contacts"].where { _age > 21 }.find_each("id") do |contact|
      #   puts contact.id
      # end
      # ```
      def find_each(primary_key : String, batch_size : Int32 = 1000, start = nil,
                    direction : String | Symbol = "asc", &)
        find_in_batches(primary_key, batch_size, start, direction) do |records|
          records.each { |rec| yield rec }
        end
      end

      def find_each(primary_key : Criteria, batch_size : Int32 = 1000, start = nil,
                    direction : String | Symbol = "asc", &)
        find_in_batches(primary_key, batch_size, start, direction) do |records|
          records.each { |rec| yield rec }
        end
      end

      def find_each(primary_key : Nil, batch_size : Int32 = 1000, start : Int32 = 0,
                    direction : String | Symbol = "asc", &)
        find_in_batches(batch_size, start) do |records|
          records.each { |rec| yield rec }
        end
      end

      def find_each(batch_size : Int32 = 1000, start : Int32 = 0, direction : String | Symbol = "asc", &)
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

        read_adapter.query(query, args) do |rs|
          begin
            rs.each { results << Record.new(read_adapter.result_to_hash(rs)) }
          rescue e : Exception
            rs.read_to_end
            raise e
          end
        end
        results
      end

      # Returns query execution explanation.
      #
      # Format depends on used database adapter.
      #
      # ```
      # Jennifer::Query["contacts"].explain # => "Seq Scan on contacts  (cost=0.00..13.40 rows=340 width=206)"
      # ```
      def explain : String
        read_adapter.explain(self)
      end

      private def read_adapter
        adapter
      end

      private def write_adapter
        adapter
      end
    end
  end
end
