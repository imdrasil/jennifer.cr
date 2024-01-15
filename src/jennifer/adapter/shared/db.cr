module DB
  abstract class Statement
    protected def around_query_or_exec(args : Enumerable, &)
      yield
    end
  end

  # NOTE: should be removed after migration to the latest crystal-db
  # :nodoc:
  module MetadataValueConverter
    # Returns *arg* encoded as a `::Log::Metadata::Value`.
    def self.arg_to_log(arg) : ::Log::Metadata::Value
      ::Log::Metadata::Value.new(arg.to_s)
    end

    # :ditto:
    def self.arg_to_log(arg : Enumerable) : ::Log::Metadata::Value
      ::Log::Metadata::Value.new(arg.to_a.map { |item| arg_to_log(item).as(::Log::Metadata::Value) })
    end

    # :ditto:
    def self.arg_to_log(arg : Int) : ::Log::Metadata::Value
      ::Log::Metadata::Value.new(arg.to_i64)
    end

    # :ditto:
    def self.arg_to_log(arg : UInt64) : ::Log::Metadata::Value
      ::Log::Metadata::Value.new(arg.to_s)
    end

    # :ditto:
    def self.arg_to_log(arg : Nil | Bool | Int32 | Int64 | Float32 | Float64 | String | Time) : ::Log::Metadata::Value
      ::Log::Metadata::Value.new(arg)
    end
  end
end
