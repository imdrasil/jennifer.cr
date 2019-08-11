module Jennifer
  module Model
    # Type converter for Postgre numeric field.
    #
    # Converts `PG::Numeric` to `Float64` and back.
    #
    # ```
    # class Order < Jennifer::Model::Base
    #   mapping(
    #     id: Primary32,
    #     total: { type: Float64?, converter: Jennifer::Model::NumericToFloat64Converter }
    #   )
    # end
    # ```
    class NumericToFloat64Converter
      def self.from_db(pull, nillable)
        if nillable
          pull.read(PG::Numeric?).try(&.to_f64)
        else
          pull.read(PG::Numeric).to_f64
        end
      end

      def self.to_db(value : Float?)
        value
      end

      def self.from_hash(hash : Hash, column)
        value = hash[column]
        case value
        when PG::Numeric
          value.to_f64
        else
          value
        end
      end
    end

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
    #     status: { type: String?, default: "draft", converter: Jennifer::Model::EnumConverter }
    #   )
    # end
    # ```
    class EnumConverter
      def self.from_db(pull, nillable)
        if nillable
          value = pull.read(Bytes?)
          value && String.new(value)
        else
          String.new(pull.read(Bytes))
        end
      end

      def self.to_db(value : String)
        value.to_slice
      end

      def self.to_db(value : Nil)
        value
      end

      def self.from_hash(hash : Hash, column)
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
end
