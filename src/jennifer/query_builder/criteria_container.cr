module Jennifer
  module QueryBuilder
    struct CriteriaContainer
      include Enumerable({Criteria, String})

      @value_bucket : Hash(String, String)
      @key_bucket : Hash(String, Criteria)

      def initialize
        @value_bucket = {} of String => String
        @key_bucket = {} of String => Criteria
      end

      def_clone

      def each
        @key_bucket.each do |internal_key, criteria|
          yield({criteria, @value_bucket.fetch(internal_key)})
        end
      end

      def keys
        @key_bucket.values
      end

      def values
        @value_bucket.values
      end

      def size
        @value_bucket.size
      end

      def []=(key : Criteria, value : String)
        internal_key = key_value(key)

        @value_bucket[internal_key] = value
        @key_bucket[internal_key] = key
        key
      end

      def [](key : Criteria)
        internal_key = key_value(key)
        @value_bucket[internal_key]
      end

      def []?(key : Criteria)
        internal_key = key_value(key)
        @value_bucket[internal_key]?
      end

      def clear
        @value_bucket.clear
        @key_bucket.clear
      end

      def empty?
        @key_bucket.empty?
      end

      def delete(key : Criteria)
        internal_key = key_value(key)

        @value_bucket.delete(internal_key)
        @key_bucket.delete(internal_key)
      end

      private def key_value(criteria : Criteria)
        criteria.field + ":::" + criteria.table
      end
    end
  end
end
