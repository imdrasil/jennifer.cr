module Jennifer
  module Adapter
    module JSONEncoder
      def self.encode(value : JSON::Any, sql_generator) : String
        jsonify(value, sql_generator).to_json
      end

      def self.jsonify(value : JSON::Any, sql_generator)
        if value.as_s?
          to_json(value.as_s, sql_generator)
        elsif value.as_h?
          to_json(value.as_h, sql_generator)
        elsif value.as_a?
          to_json(value.as_a, sql_generator)
        else
          value
        end
      end

      def self.to_json(value : String, sql_generator)
        JSON::Any.new(sql_generator.quote_json_string(value))
      end

      def self.to_json(value : Hash, sql_generator)
        result = {} of String => JSON::Any
        value.each do |key, key_value|
          result[sql_generator.quote_json_string(key)] = jsonify(key_value, sql_generator)
        end
        JSON::Any.new(result)
      end

      def self.to_json(value : Array, sql_generator)
        result = [] of JSON::Any
        value.each { |element| result << jsonify(element, sql_generator) }
        JSON::Any.new(result)
      end
    end
  end
end
