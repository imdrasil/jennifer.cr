# Stubs for all adapters. Is added here to allow making general DBAny alias for
# all adapters
module PG
  struct Numeric
    def initialize(ndigits, weight, sign, dscale, digits)
    end
  end

  module Geo
    {% for type in %w(Point Line Circle LineSegment Box Path Polygon) %}
      struct {{type.id}}
      end
    {% end %}
  end
end
