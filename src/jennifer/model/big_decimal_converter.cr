require "big/big_decimal"

module Jennifer::Model
  # Type converter for numeric field.
  #
  # Converts `PG::Numeric` (for PostgreSQL) or `Float64` data types (for MySQL) field to `BigDecimal` and back.
  # This allows to map numeric fields to `BigDecimal` which allows to manipulate float numbers with fixed scale.
  # It is important to specify scale value - the count of decimal digits in the fractional part, to the right of
  # the decimal point.
  #
  # ```
  # class Order < Jennifer::Model::Base
  #   mapping(
  #     id: Primary32,
  #     # for MySQL use Float64
  #     total: {type: BigDecimal?, converter: Jennifer::Model::BigDecimalConverter(PG::Numeric), scale: 2}
  #   )
  # end
  # ```
  module BigDecimalConverter(T)
    def self.from_db(pull, options)
      raise BaseException.new("BigDecimal type require 'scale' option") unless options.has_key?(:scale)

      scale = options[:scale]?.not_nil!
      if options[:null]
        value = pull.read(T?)
        value && BigDecimal.new((value.to_f64 * 10 ** scale).to_i, scale)
      else
        value = pull.read(T)
        BigDecimal.new((value.to_f64 * 10 ** scale).to_i, scale)
      end
    end

    def self.to_db(value : BigDecimal, options)
      value.to_f64
    end

    def self.to_db(value : Nil, options) : Nil
    end

    def self.from_hash(hash : Hash, column, options)
      raise BaseException.new("BigDecimal type require 'scale' option") unless options.has_key?(:scale)

      scale = options[:scale]
      value = hash[column]
      case value
      when T, Float, Int
        BigDecimal.new((value.to_f64 * 10 ** scale).to_i, scale)
      when String
        coerce(value, options)
      else
        value
      end
    end

    def self.coerce(value : String, _options) : BigDecimal?
      BigDecimal.new(value) unless value.empty?
    end
  end
end
