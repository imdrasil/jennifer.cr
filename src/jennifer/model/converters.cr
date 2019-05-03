module Jennifer
  module Model
    # Default converter for `JSON::Any` fields.
    #
    # Converts json string to `JSON::Any` and back.
    class JSONConverter
      def self.from_db(pull, nillable)
        nillable ? pull.read(JSON::Any?) : pull.read(JSON::Any)
      end

      def self.to_db(value : JSON::Any)
        value.to_json
      end

      def self.to_db(value : Nil)
        value
      end

      def self.from_hash(hash : Hash, column)
        value = hash[column]
        case value
        when String
          JSON.parse(value)
        else
          value
        end
      end
    end
  end
end
