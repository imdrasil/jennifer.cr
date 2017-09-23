module Jennifer
  module Adapter
    module Sanitizer
      TIME_FORMAT = "%F %X.%L"

      def escape(value : Nil)
        "NULL"
      end

      def escape(val : Bool)
        val ? "'t'" : "'f'"
      end

      def escape(value : Time)
        "'#{value.to_s(TIME_FORMAT)}'"
      end

      def escape(val : String)
        "'" + val.gsub(/["']/) { |s| '\\' + s } + "'"
      end

      def escape(val : Bool)
        val ? "TRUE" : "FALSE"
      end

      def escape(val : JSON::Any)
        "'#{val.to_json}'"
      end

      def escape(val : QueryBuilder::Criteria)
        val.as_sql
      end

      def escape(val)
        val.to_s
      end
    end
  end
end
