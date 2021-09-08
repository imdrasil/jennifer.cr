module Jennifer
  module Postgres
    module Quoting
      def quote(value : String)
        PG::EscapeHelper.escape_literal(value)
      end

      def quote(value : PG::Geo::Box)
        "'((#{value.x1},#{value.y1}),(#{value.x2},#{value.y2}))'"
      end

      def quote(value : PG::Geo::Circle)
        "'<(#{value.x},#{value.y}),#{value.radius}>'"
      end

      def quote(value : PG::Geo::Line)
        "'{#{value.a},#{value.b},#{value.c} }'"
      end

      def quote(value : PG::Geo::LineSegment)
        "'[(#{value.x1},#{value.y1}),(#{value.x2},#{value.y2})]'"
      end

      def quote(value : PG::Geo::Path)
        String.build do |io|
          io << "'["
          value.points.each_with_index do |point, index|
            io << ',' if index != 0
            io << quote(point, false)
          end
          io << "]'"
        end
      end

      def quote(value : PG::Geo::Point, quote = true)
        return "'(#{value.x},#{value.y})'" if quote

        "(#{value.x},#{value.y})"
      end

      def quote(value : PG::Geo::Polygon)
        String.build do |io|
          io << "'("
          value.points.each_with_index do |point, index|
            io << ',' if index != 0
            io << quote(point, false)
          end
          io << ")'"
        end
      end

      def quote(value : PG::Numeric)
        value.to_s
      end

      def quote(value : Array)
        String.build do |io|
          io << "'{"
          value.each_with_index do |element, index|
            io << ',' if index != 0
            io << quote_array_value(element)
          end
          io << "}'"
        end
      end

      def quote(value : Slice(UInt8))
        PG::EscapeHelper.escape_literal(value)
      end

      def quote_array_value(value : String)
        "\"" + value.gsub(Jennifer::Adapter::Quoting::STRING_QUOTING_PATTERNS) + "\""
      end

      def quote_array_value(value)
        value.to_s
      end

      def quote_identifier(identifier : String | Symbol)
        PG::EscapeHelper.escape_identifier(identifier.to_s)
      end

      def quote_table(table : String)
        %("#{table.gsub('.', %("."))}")
      end
    end
  end
end
