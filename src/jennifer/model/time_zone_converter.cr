module Jennifer::Model
  # Default converter for `Time` fields.
  #
  # Converts time to `Jennifer::Config.local_time_zone`.
  class TimeZoneConverter
    DATE_FORMAT      = "%F"
    TIME_FORMAT      = "%H:%M"
    DATE_TIME_FORMAT = "#{DATE_FORMAT} %T"
    TIME_REGEXP      = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/

    def self.from_db(pull, options)
      value = pull.read(options[:null] ? Time? : Time)
      return unless value

      if !Config.time_zone_aware_attributes || options[:time_zone_aware]? == false
        value.to_local_in(Config.local_time_zone)
      else
        value.in(Config.local_time_zone)
      end
    end

    # Returns time *as is* as any *Time* object is converted to UTC automatically by query builder.
    #
    # If `:time_zone_aware` is `false` - changes time zone to application one instead of converting.
    def self.to_db(value : Time, options)
      return value.to_local_in(Time::Location::UTC) if options[:time_zone_aware]? == false

      value
    end

    def self.to_db(value : Nil, options); end

    def self.from_hash(hash : Hash, column, options)
      value = hash[column]
      case value
      when Time
        if !Config.time_zone_aware_attributes || options[:time_zone_aware]? == false
          value.to_local_in(Config.local_time_zone)
        else
          value.in(Config.local_time_zone)
        end
      when String
        coerce(value, options)
      else
        value
      end
    end

    # Coerces string to *Time*
    def self.coerce(value : String, options) : Time?
      return if value.empty?
      return parse_time(value, options[:time_format]? || default_time_format) if time?(value)

      format =
        if date_time?(value)
          options[:date_time_format]? || default_date_time_format
        else
          options[:date_format]? || default_date_format
        end
      Time.parse(value, format, Config.local_time_zone)
    end

    # Returns default date-time format to coerce `String` to `Time`
    def self.default_date_time_format
      DATE_TIME_FORMAT
    end

    # Returns default date format to coerce `String` to `Time`
    def self.default_date_format
      DATE_FORMAT
    end

    # Returns default time format to coerce `String` to `Time`
    def self.default_time_format
      TIME_FORMAT
    end

    # Returns whether given string has a date-time format
    def self.date_time?(value : String) : Bool
      / /.matches?(value)
    end

    # Returns whether given string has a time format
    def self.time?(value : String) : Bool
      TIME_REGEXP.matches?(value)
    end

    private def self.parse_time(value : String, format : String)
      parsed_time = Time.parse(value, format, Config.local_time_zone)
      Time.local(
        1970,
        1,
        2,
        parsed_time.hour,
        parsed_time.minute,
        parsed_time.second,
        nanosecond: parsed_time.nanosecond,
        location: Config.local_time_zone
      )
    end
  end
end
