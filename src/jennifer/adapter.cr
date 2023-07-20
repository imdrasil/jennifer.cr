require "./adapter/base"

module Jennifer
  # All possible database types for any driver.
  alias DBAny = Array(Int32) | Array(Char) | Array(Float32) | Array(Float64) |
                Array(Int16) | Array(Int64) | Array(String) | Array(UUID) | Array(Bool) | Array(Time) |
                Bool | Char | Float32 | Float64 | Int8 | Int16 | Int32 | Int64 | JSON::Any | JSON::PullParser |
                String | Time | Nil | PG::Geo::Box | PG::Geo::Circle | PG::Geo::Line | PG::Geo::LineSegment |
                PG::Geo::Path | PG::Geo::Point | PG::Geo::Polygon | PG::Numeric | Slice(UInt8) | Time::Span | UInt32 |
                UUID

  module Adapter
    TYPES = %i(
      tinyint integer short bigint oid
      float double
      numeric decimal
      bool
      string char text varchar blchar
      uuid
      timestamp timestamptz date_time date
      blob bytea
      json jsonb xml
      point lseg path box polygon line circle
    )

    @@default_adapter : Base?
    @@adapters = {} of String => Base.class
    @@default_adapter_class : Base.class | Nil

    # Returns adapter instance.
    #
    # The first call of this method greps all models table column numbers.
    def self.default_adapter
      @@default_adapter ||= default_adapter_class.not_nil!.new(Config.instance)
    end

    @[Deprecated("Use .default_adapter instead")]
    def self.adapter
      default_adapter
    end

    @[Deprecated("Use .default_adapter_class instead")]
    def self.adapter_class
      default_adapter_class
    end

    # Returns adapter class.
    def self.default_adapter_class
      @@default_adapter_class ||= adapters[Config.adapter]
    rescue e : KeyError
      if Config.adapter.empty?
        raise BaseException.new(
          "It seems you are trying to initialize adapter before setting Jennifer configurations. " \
          "Ensure that you require adapter and load configurations."
        )
      end
      raise BaseException.new("Unregistered adapter `#{Config.adapter}`")
    end

    # Returns hash with all registered adapter classes
    def self.adapters
      @@adapters
    end

    # Registers adapter *adapter_class* with name *name*.
    def self.register_adapter(name : String, adapter_class)
      adapters[name] = adapter_class
    end
  end
end
