module Jennifer
  module Adapter
    module Sanitizer
      def escape(value : Nil)
        "NULL"
      end

      def escape(value : QueryBuilder::Criteria)
        value.as_sql
      end

      def escape(value : Array)
        escape_array(value)
      end

      def escape(value : Time)
        "'#{value.to_s(PQ::ISO_8601)}'"
      end

      def escape(val : PG::Geo::Point)
        "(#{val.x},#{val.y})"
      end

      def escape(val : PG::Geo::Line)
        "{#{val.a},#{val.b},#{val.c}}"
      end

      def escape(val : PG::Geo::Circle)
        "<(#{val.x},#{val.y}),#{val.radius}>"
      end

      def escape(val : PG::Geo::LineSegment)
        "((#{val.x1},#{val.y1}),(#{val.x2},#{val.y2}))"
      end

      def escape(val : PG::Geo::Box)
        "((#{val.x1},#{val.y1}),(#{val.x2},#{val.y2}))"
      end

      def escape(val : PG::Geo::Path)
        if val.closed?
          encode_points "(", val.points, ")"
        else
          encode_points "[", val.points, "]"
        end
      end

      def escape(val : PG::Geo::Polygon)
        encode_points "(", val.points, ")"
      end

      def escape(val : String)
        "'" + val.gsub(/["']/) { |s| '\\' + s } + "'"
      end

      def escape(val : Array(UInt8))
        backslashes = "\\\\"
        String.build do |s|
          s << "E'"
          val.each do |el|
            s << backslashes
            el.to_s(8, s)
          end
          s << "'"
        end
      end

      def escape(val : Bool)
        val ? "'t'" : "'f'"
      end

      def escape(val : JSON::Any)
        "'#{val.to_json}'::json"
      end

      def escape(val : Number | PG::Numeric)
        val.to_s
      end

      def escape(val)
        escape(val.to_s)
      end

      def escape_array(array)
        String.build do |io|
          encode_array(array, io)
        end
      end

      private def encode_array(value : Array, io)
        io << "'{"
        value.join(",", io) { |e| encode_array(e, io) }
        io << "}'"
      end

      private def encode_array(value : String, io)
        io << escape(value)
      end

      private def encode_array(value, io)
        io << value
      end

      private def encode_points(left, points, right)
        String.build do |io|
          io << left
          points.each_with_index do |point, i|
            io << "," if i > 0
            io << "(" << point.x << "," << point.y << ")"
          end
          io << right
        end
      end
    end
  end
end
