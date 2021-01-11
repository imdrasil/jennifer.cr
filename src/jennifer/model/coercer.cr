module Jennifer::Model
  module Coercer
    DATE_TIME_FORMAT = "%F %T"
    DATE_FORMAT = "%F"

    def self.to_s(value : String)
      value
    end

    def self.to_pr64(value : String)
      to_i64(value)
    end

    def self.to_s(value : String)
      value
    end

    def self.to_i16(value : String)
      value.to_i16
    end

    def self.to_i64(value : String)
      value.to_i64
    end

    def self.to_i(value : String)
      value.to_i
    end

    def self.to_f(value : String)
      value.to_f
    end

    def self.to_f32(value : String)
      value.to_f32
    end

    def self.to_bool(value : String)
      value == "true" || value == "1" || value == "t"
    end

    def self.to_json(value : String)
      JSON.parse(value)
    end

    def self.to_time(value : String)
      format = value =~ / / ? DATE_TIME_FORMAT : DATE_FORMAT
      Time.parse(value, format, Config.local_time_zone)
    end
  end
end
