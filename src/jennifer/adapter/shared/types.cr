# Stubs for all adapters. Is added here to allow making general DBAny alias for
# all adapters.

# :nodoc:
module PG
  struct Numeric
    def_clone

    def to_json
      JSON.build do |json|
        to_json(json)
      end
    end

    def to_json(json : JSON::Builder)
      json.string to_s
    end

    def self.build(*args)
      raise "This is a stub for pg driver"
    end
  end

  module Geo
    {% for type in %w(Point Line Circle LineSegment Box Path Polygon) %}
      struct {{type.id}}
        include JSON::Serializable

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

  struct Span
    def_clone
  end

  class Location
    def_clone

    struct Zone
      def_clone
    end
  end
end

# :nodoc:
struct JSON::Any
  def_clone
end

# :nodoc:
struct UUID
  def_clone
end

# :nodoc:
class JSON::PullParser
  def to_json(json : JSON::Builder)
    read_raw(json)
  end

  def clone
    string =
      if @lexer.is_a?(JSON::Lexer::StringBased)
        @lexer.as(JSON::Lexer::StringBased).@reader.@string
      else
        raise ArgumentError.new
      end
    JSON::PullParser.new(string)
  end
end
