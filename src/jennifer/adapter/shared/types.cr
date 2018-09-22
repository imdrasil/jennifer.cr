# Stubs for all adapters. Is added here to allow making general DBAny alias for
# all adapters.
module PG
  # :nodoc:
  struct Numeric
    def_clone

    def self.build(*args)
      raise "This is a stub for pg driver"
    end
  end

  module Geo
    {% for type in %w(Point Line Circle LineSegment Box Path Polygon) %}
      # :nodoc:
      struct {{type.id}}
        def_clone

        def self.build(*args)
          raise "This is a stub for pg driver"
        end
      end
    {% end %}
  end
end

# :nodoc:
struct Time
  def_clone

  # :nodoc:
  struct Span
    def_clone
  end
end

# :nodoc:
class Time::Location
  def_clone

  # :nodoc:
  struct Zone
    def_clone
  end
end

# :nodoc:
struct JSON::Any
  def_clone
end
