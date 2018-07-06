module Jennifer
  module QueryBuilder
    module Executables
      def last
        reverse_order
        old_limit = @limit
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        reverse_order
        r
      end

      def last!
        old_limit = @limit
        @limit = 1
        reverse_order
        result = to_a
        reverse_order
        @limit = old_limit
        raise RecordNotFound.new(adapter.sql_generator.select(self)) if result.empty?
        result[0]
      end

      def first
        old_limit = @limit
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        r
      end

      def first!
        old_limit = @limit
        result = to_a
        @limit = old_limit
        raise RecordNotFound.new(adapter.sql_generator.select(self)) if result.empty?
        result[0]
      end

      def pluck(fields : Array)
        adapter.pluck(self, fields.map(&.to_s))
      end

      def pluck(field : String | Symbol)
        adapter.pluck(self, field.to_s)
      end

      def pluck(*fields : String | Symbol)
        adapter.pluck(self, fields.to_a.map(&.to_s))
      end

      def delete
        adapter.delete(self)
      end

      def exists?
        adapter.exists?(self)
      end

      # skips any callbacks and validations
      def modify(options : Hash)
        adapter.modify(self, options)
      end

      def update(options : Hash)
        adapter.update(self, options)
      end

      def update(**options)
        update(options.to_h)
      end

      # skips all callbacks and validations
      def increment(fields : Hash)
        hash = {} of Symbol | String => NamedTuple(value: DBAny, operator: Symbol)
        fields.each do |k, v|
          hash[k] = {value: v, operator: :+}
        end
        modify(hash)
      end

      # skips all callbacks and validations
      def increment(**fields)
        hash = {} of Symbol | String => NamedTuple(value: DBAny, operator: Symbol)
        fields.each do |k, v|
          hash[k] = {value: v, operator: :+}
        end
        modify(hash)
      end

      # skips any callbacks and validations
      def decrement(fields : Hash)
        hash = {} of Symbol | String => NamedTuple(value: DBAny, operator: Symbol)
        fields.each do |k, v|
          hash[k] = {value: v, operator: :-}
        end
        modify(hash)
      end

      # skips any callbacks and validations
      def decrement(**fields)
        hash = {} of Symbol | String => NamedTuple(value: DBAny, operator: Symbol)
        fields.each do |k, v|
          hash[k] = {value: v, operator: :-}
        end
        modify(hash)
      end

      def to_a
        results
      end

      def db_results
        result = [] of Hash(String, DBAny)
        return result if @do_nothing
        each_result_set do |rs|
          result << adapter.result_to_hash(rs)
        end
        result
      end

      def results
        result = [] of Record
        return result if @do_nothing
        each_result_set { |rs| result << Record.new(rs) }
        result
      end

      # works only if there is id field and it is covertable to Int32
      def ids
        pluck(:id).map(&.as(Int32))
      end

      def each
        to_a.each do |e|
          yield e
        end
      end

      def each_result_set(&block)
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

      def find_in_batches(primary_key : Criteria, batch_size : Int32 = 1000, start = nil, direction : String | Symbol = "asc", &block)
        Config.logger.warn("#find_in_batches is invoked with already ordered query - it will be reordered") if ordered?
        request = clone.reorder({primary_key => direction.to_s}).limit(batch_size)

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
                          " key field name which may results in not proper records extraction; 'start' argument" \
                          " was realized as page number.")
        request = clone.reorder({} of String => String).limit(batch_size)

        records = request.offset(start * batch_size).to_a
        while records.any?
          records_size = records.size
          yield records
          break if records_size < batch_size
          start += 1
          records = request.offset(start * batch_size).to_a
        end
      end

      def find_in_batches(batch_size : Int32 = 1000, start : Int32 = 0, &block)
        find_in_batches(nil, batch_size, start) { |records| yield records }
      end

      def find_in_batches(primary_key : String, batch_size : Int32 = 1000, start : Int32? = nil, direction : String | Symbol = "asc", &block)
        find_in_batches(@expression.c(primary_key.not_nil!), batch_size, start, direction) { |records| yield records }
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

      def find_each(primary_key : String, batch_size : Int32 = 1000, start = nil, direction : String | Symbol = "asc", &block)
        find_in_batches(primary_key, batch_size, start, direction) do |records|
          records.each { |rec| yield rec }
        end
      end

      def find_records_by_sql(query : String, args : Array(DBAny) = [] of DBAny)
        results = [] of Record
        return results if @do_nothing
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
