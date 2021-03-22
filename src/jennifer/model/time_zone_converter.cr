module Jennifer::Model
  # Default converter for `Time` fields.
  #
  # Converts time to `Jennifer::Config.local_time_zone`.
  class TimeZoneConverter
    def self.from_db(pull, options)
      value = pull.read(options[:null] ? Time? : Time)
      return unless value

      value.in(Config.local_time_zone)
    end

    # Returns time as is as any *Time* object is converted to UTC automatically by query builder.
    def self.to_db(value, options)
      value
    end

    def self.from_hash(hash : Hash, column, options)
      value = hash[column]
      case value
      when Time
        value.in(Config.local_time_zone)
      else
        value
      end
    end
  end
end
