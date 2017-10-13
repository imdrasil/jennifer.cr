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
        raise RecordNotFound.new(Adapter::SqlGenerator.select(self)) if result.empty?
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
        raise RecordNotFound.new(Adapter::SqlGenerator.select(self)) if result.empty?
        result[0]
      end

      def pluck(fields : Array)
        ::Jennifer::Adapter.adapter.pluck(self, fields.map(&.to_s))
      end

      def pluck(field : String | Symbol)
        ::Jennifer::Adapter.adapter.pluck(self, field.to_s)
      end

      def pluck(*fields : String | Symbol)
        ::Jennifer::Adapter.adapter.pluck(self, fields.to_a.map(&.to_s))
      end

      def delete
        ::Jennifer::Adapter.adapter.delete(self)
      end

      def exists?
        ::Jennifer::Adapter.adapter.exists?(self)
      end

      def count : Int32
        ::Jennifer::Adapter.adapter.count(self)
      end

      # skips any callbacks and validations
      def modify(options : Hash)
        ::Jennifer::Adapter.adapter.modify(self, options)
      end

      def update(options : Hash)
        ::Jennifer::Adapter.adapter.update(self, options)
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
          result << Adapter.adapter.result_to_hash(rs)
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
        pluck(:id).map(&.to_i)
      end

      def each
        to_a.each do |e|
          yield e
        end
      end

      def each_result_set(&block)
        ::Jennifer::Adapter.adapter.select(self) do |rs|
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

      def find_in_batches(start = nil, batch_size : Int32 = 1000, primary_key : Criteria? = nil, &block)
        if primary_key.nil?
          start ||= 0
          Config.logger.warn("#find_in_batches methods was called without passing primary_key" \
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
        else
          primary_key = primary_key.not_nil!
          request = clone.reorder({primary_key => "asc"}).limit(batch_size)

          records = start ? request.clone.where { primary_key >= start }.to_a : request.to_a
          while records.any?
            records_size = records.size
            primary_key_offset = records.last.attribute(primary_key.field)
            yield records
            break if records_size < batch_size
            records = request.clone.where { primary_key > primary_key_offset }.to_a
          end
        end
      end

      def find_in_batches(start = nil, batch_size : Int32 = 1000, primary_key : String? = nil, &block)
        raise ArgumentError.new("Primary key shoulb not be nil") if primary_key.nil?
        find_in_batches(start, batch_size, @expression.c(primary_key.not_nil!)) { |records| yield records }
      end

      def find_records_by_sql(query : String, args : Array(DBAny) = [] of DBAny)
        results = [] of Record
        return results if @do_nothing
        ::Jennifer::Adapter.adapter.query(query, args) do |rs|
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
