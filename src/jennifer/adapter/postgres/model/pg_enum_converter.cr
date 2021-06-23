module Jennifer::Model
  # Type converter for Postgre ENUM field.
  #
  # Postgre custom data types (to which ENUM belongs) may have different OID on different databases.
  # Therefore PG driver treats value of ENUM type as `Bytes`. To bring dynamic convert to string value and back
  # use this converter
  #
  # ```
  # class Order < Jennifer::Model::Base
  #   mapping(
  #     id: Primary32,
  #     title: String,
  #     status: {type: String?, default: "draft", converter: Jennifer::Model::PgEnumConverter}
  #   )
  # end
  # ```
  class PgEnumConverter
    def self.from_db(pull, options)
      if options[:null]
        value = pull.read(Bytes?)
        value && String.new(value)
      else
        String.new(pull.read(Bytes))
      end
    end

    def self.to_db(value : String, options)
      value.to_slice
    end

    def self.to_db(value : Nil, options) : Nil
    end

    def self.from_hash(hash : Hash, column, options)
      value = hash[column]
      case value
      when Bytes
        String.new(value)
      else
        value
      end
    end
  end
end
