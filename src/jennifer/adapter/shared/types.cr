# Stubs for all adapters. Is added here to allow making general DBAny alias for
# all adapters.
module PG
  struct Numeric
    def_clone

    def self.build(*args)
      raise "This is a stub for pg driver"
    end
  end

  module Geo
    {% for type in %w(Point Line Circle LineSegment Box Path Polygon) %}
      struct {{type.id}}
        def_clone

        def self.build(*args)
          raise "This is a stub for pg driver"
        end
      end
    {% end %}
  end
end

struct Time
  def_clone

  struct Span
    def_clone
  end
end

class Time::Location
  def_clone

  struct Zone
    def_clone
  end
end

struct JSON::Any
  def_clone
end
