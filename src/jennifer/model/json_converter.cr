module Jennifer::Model
  # Default converter for `JSON::Any` fields.
  #
  # Converts json string to `JSON::Any` and back.
  class JSONConverter
    def self.from_db(pull, options)
      pull.read(options[:null] ? JSON::Any? : JSON::Any)
    end

    def self.to_db(value : JSON::Any, options) : String
      value.to_json
    end

    def self.to_db(value : Nil, options) : Nil
    end

    def self.from_hash(hash : Hash, column, options)
      value = hash[column]
      case value
      when String
        JSON.parse(value)
      when JSON::PullParser
        JSON::Any.new(value)
      else
        value
      end
    end

    def self.coerce(value : String, _options) : JSON::Any?
      JSON.parse(value) unless value.empty?
    end
  end
end
