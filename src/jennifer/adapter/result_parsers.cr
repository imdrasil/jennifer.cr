module Jennifer
  module Adapter
    module ResultParsers
      def result_to_array_by_names(rs, names : Array(String))
        buf = {} of String => DBAny
        names.each { |name| buf[name] = nil }
        count = names.size
        rs.columns.each do |column|
          column_name = column.name
          if buf.has_key?(column_name)
            buf[column_name] = read_column(rs, column)
            count -= 1
          else
            rs.read
          end
          break if count == 0
        end
        # NOTE: all fields are already sorted in a request
        buf.values
      end

      # Converts single ResultSet to hash
      def result_to_hash(rs)
        result = {} of String => DBAny
        rs.columns.each do |column|
          result[column.name] = read_column(rs, column)
        end
        result
      end

      # Reads *column*'s value from given result set.
      abstract def read_column(rs, column)

      def read_column(rs, column)
        value = rs.read.as(DBAny)
        return value unless value.is_a?(Time)

        set_time_column_zone(value)
      end

      private def set_time_column_zone(value)
        if Config.time_zone_aware_attributes
          value.in(Config.local_time_zone)
        else
          value.to_local_in(Config.local_time_zone)
        end
      end
    end
  end
end
