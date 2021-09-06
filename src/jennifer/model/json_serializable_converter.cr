module Jennifer::Model
  # Allows to serialize/deserialize JSON column to/from *T*.
  #
  # ```
  # class Location
  #   include JSON::Serializable
  #
  #   property latitude : Float64
  #   property longitude : Float64
  # end
  #
  # class User < Jennifer::Model::Base
  #   mapping(
  #     # ...
  #     location: {type: Location, converter: Jennifer::Model::JSONSerializableConverter(Location)}
  #   )
  # end
  # ```
  class JSONSerializableConverter(T)
    def self.from_db(pull, options)
      value = pull.read(options[:null] ? JSON::Any? : JSON::Any)
      return unless value

      T.from_json(value.to_json)
    end

    def self.to_db(value : T, options) : String
      value.to_json
    end

    def self.to_db(value : Nil, options) : Nil
    end

    def self.from_hash(hash : Hash, column, options)
      value = hash[column]
      case value
      when String
        T.from_json(value)
      when JSON::Any
        T.from_json(value.to_json)
      else
        value
      end
    end
  end
end
