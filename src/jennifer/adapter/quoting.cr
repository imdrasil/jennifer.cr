module Jennifer
  module Adapter
    module Quoting
      ARGUMENT_ESCAPE_STRING  = "%s"
      STRING_QUOTING_PATTERNS = {'\\' => "\\\\", '\'' => "''", '"' => "\\\""}

      # Quotes the column value to help prevent -[SQL injection attacks][https://en.wikipedia.org/wiki/SQL_injection].
      abstract def quote(value : String)

      # Quotes the given identifier according to the language specification to prevent overlappings with predefined
      # keywords.
      abstract def quote_identifier(identifier : String | Symbol)

      # Quotes the given table name according to the language specification.
      #
      # Dot inside of name is allowed to specify schema name.
      abstract def quote_table(table : String)

      def quote_identifiers(identifiers)
        identifiers.map { |id| quote_identifier(id) }
      end

      abstract def quote_json_string(value : String)

      # :ditto:
      def quote(value : Nil)
        "NULL"
      end

      # :ditto:
      def quote(value : Bool)
        value ? "TRUE" : "FALSE"
      end

      # :ditto:
      def quote(value : Int | Float | UInt32)
        value.to_s
      end

      # :ditto:
      def quote(value : Char)
        quote(value.to_s)
      end

      # :ditto:
      def quote(value : Time)
        "'#{value.to_utc.to_s("%F %T")}'"
      end

      # :ditto:
      def quote(value : Time::Span)
        # NOTE: isn't user by pg driver ATM
        "'#{value}'"
      end

      # :ditto:
      def quote(value : Slice(UInt8))
        "x'#{value.hexstring}'"
      end

      # :ditto:
      def quote(value : JSON::Any)
        "'" + ::Jennifer::Adapter::JSONEncoder.encode(value, self) + "'"
      end

      # :ditto:
      def quote(value : JSON::PullParser)
        "'" + ::Jennifer::Adapter::JSONEncoder.encode(JSON::Any.from_json(value.read_raw), self) + "'"
      end

      # :ditto:
      def quote(value)
        raise ArgumentError.new("Value #{value} can't be quoted")
      end

      # Quotes strings of JSON column value to help prevent -[SQL injection attacks][https://en.wikipedia.org/wiki/SQL_injection].
      def quote_json_string(value : String)
        value.gsub('\'', "''")
      end

      def filter_out(arg)
        escape_string
      end

      def escape_string
        ARGUMENT_ESCAPE_STRING
      end

      def escape_string(size : Int32)
        case size
        when 1
          ARGUMENT_ESCAPE_STRING
        when 2
          "#{ARGUMENT_ESCAPE_STRING}, #{ARGUMENT_ESCAPE_STRING}"
        when 3
          "#{ARGUMENT_ESCAPE_STRING}, #{ARGUMENT_ESCAPE_STRING}, #{ARGUMENT_ESCAPE_STRING}"
        else
          size.times.join(", ") { ARGUMENT_ESCAPE_STRING }
        end
      end

      def filter_out(arg : Array, single : Bool = true)
        single ? escape_string : arg.join(", ") { |item| filter_out(item) }
      end

      def filter_out(arg : QueryBuilder::SQLNode)
        arg.as_sql(self)
      end
    end
  end
end
