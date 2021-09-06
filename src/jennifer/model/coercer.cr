module Jennifer::Model
  module Coercer
    DATE_TIME_FORMAT = "%F %T"
    DATE_FORMAT      = "%F"

    def self.coerce(value : String, type : (Int8?).class)
      return nil if value.empty?

      value.to_i8
    end

    def self.coerce(value : String, type : (Int16?).class)
      return nil if value.empty?

      value.to_i16
    end

    def self.coerce(value : String, type : (Int32?).class)
      return nil if value.empty?

      value.to_i
    end

    def self.coerce(value : String, type : (Int64?).class)
      return nil if value.empty?

      value.to_i64
    end

    def self.coerce(value : String, type : (String?).class)
      return nil if value.empty?

      value
    end

    def self.coerce(value : String, type : (Float32?).class)
      return nil if value.empty?

      value.to_f32
    end

    def self.coerce(value : String, type : (Float64?).class)
      return nil if value.empty?

      value.to_f
    end

    def self.coerce(value : String, type : (Bool?).class)
      return nil if value.empty?

      value == "true" || value == "1" || value == "t"
    end

    def self.coerce(value : String, type : (BigDecimal?).class)
      return if value.empty?

      BigDecimal.new(value)
    end

    def self.coerce(value : String, type : (UUID?).class)
      return if value.empty?

      UUID.new(value)
    end

    # TODO: add PG::Numeric support
    def self.coerce(value : String, type)
      raise ::Jennifer::BaseException.new("Type #{type} can't be coerced")
    end
  end
end
