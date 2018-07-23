require "./adapter/base"

module Jennifer
  alias AnyResult = DBAny | Int8 | Int16 | JSON::Any
  alias AnyArgument = AnyResult | Array(AnyResult)

  alias DBAny = Array(Int32) | Array(Char) | Array(Float32) | Array(Float64) |
                Array(Int16) | Array(Int64) | Array(String) |
                Bool | Char | Float32 | Float64 | Int8 | Int16 | Int32 | Int64 | JSON::Any | PG::Geo::Box |
                PG::Geo::Circle | PG::Geo::Line | PG::Geo::LineSegment | PG::Geo::Path | PG::Geo::Point |
                PG::Geo::Polygon | PG::Numeric | Slice(UInt8) | String | Time | Time::Span | UInt32 | Nil

  module Adapter
    TYPES = %i(
      integer short bigint oid
      float double
      numeric decimal
      bool
      string char text var_string varchar blchar
      uuid
      timestamp timestamptz date_time
      blob bytea
      json jsonb xml
      point lseg path box polygon line circle
    )

    @@adapter : Base?
    @@adapters = {} of String => Base.class
    @@adapter_class : Base.class | Nil

    {% for method in [:exec, :scalar] %}
      def self.{{method.id}}(*opts)
        adapter.{{method.id}}(*opts)
      end
    {% end %}

    def self.query(_query, args = [] of DBAny)
      adapter.query(_query, args) { |rs| yield rs }
    end

    # :nodoc:
    # Allows to assign newly created adapter and call setupe methods with existing adapter
    private def self.adapter=(_adapter)
      @@adapter = _adapter
    end

    def self.adapter
      @@adapter ||= begin
        a = adapter_class.not_nil!.build
        self.adapter = a
        a.prepare
        a
      end
    end

    # Returns default adapter.
    #
    # NOTE: this is a temporary solution to decouple adapter dependency or query class.
    def self.default_adapter
      adapter
    end

    def self.default_adapter_class
      adapter_class
    end

    def self.adapter_class
      @@adapter_class ||= adapters[Config.adapter]
    end

    def self.adapters
      @@adapters
    end

    def self.register_adapter(name, adapter)
      adapters[name] = adapter
    end
  end
end
