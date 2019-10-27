module Jennifer
  module Adapter
    module ResultParsers
      def result_to_array_by_names(rs, names : Array(String))
        buf = {} of String => DBAny
        names.each { |name| buf[name] = nil }
        count = names.size
        rs.each_column do |column|
          if buf.has_key?(column)
            buf[column] = rs.read.as(DBAny)
            if buf[column].is_a?(Int8)
              buf[column] = (buf[column] == 1i8).as(Bool)
            end
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
        rs.each_column { |column| result[column] = rs.read.as(DBAny) }
        result
      end
    end
  end
end
