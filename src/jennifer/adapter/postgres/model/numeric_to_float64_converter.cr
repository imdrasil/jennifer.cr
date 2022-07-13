module Jennifer::Model
  # Type converter for Postgre numeric field.
  #
  # Converts `PG::Numeric` to `Float64` and back.
  #
  # ```
  # class Order < Jennifer::Model::Base
  #   mapping(
  #     id: Primary32,
  #     total: {type: Float64?, converter: Jennifer::Model::NumericToFloat64Converter}
  #   )
  # end
  # ```
  class NumericToFloat64Converter
    def self.from_db(pull, options)
      if options[:null]
        pull.read(PG::Numeric?).try(&.to_f64)
      else
        pull.read(PG::Numeric).to_f64
      end
    end

    def self.to_db(value : Float?, options)
      value
    end

    def self.from_hash(hash : Hash, column, options)
      value = hash[column]
      case value
      when PG::Numeric, String
        value.to_f64
      else
        value
      end
    end
  end
end
