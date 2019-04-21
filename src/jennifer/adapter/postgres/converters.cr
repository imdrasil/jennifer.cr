module Jennifer
  module Model
    # Type converter for Postgre numeric field.
    #
    # Converts `PG::Numeric` to `Float64` and back.
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
  end
end
