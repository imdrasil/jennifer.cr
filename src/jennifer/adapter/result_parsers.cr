module Jennifer
  module Adapter
    module ResultParsers
      def result_to_array(rs)
        a = [] of DBAny
        rs.each_column do
          temp = rs.read(DBAny)
          temp = (temp == 1i8).as(Bool) if temp.is_a?(Int8)
          a << temp
        end
        a
      end

      def result_to_array_by_names(rs, names : Array)
        buf = {} of String => DBAny
        names.each { |n| buf[n] = nil }
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

      # converts single ResultSet to hash
      def result_to_hash(rs)
        h = {} of String => DBAny
        rs.each_column do |column|
          h[column] = rs.read.as(DBAny)
          if h[column].is_a?(Int8)
            h[column] = (h[column] == 1i8).as(Bool)
          end
        end
        h
      end

      # converts single ResultSet which contains several tables
      def table_row_hash(rs)
        h = {} of String => Hash(String, DBAny)
        rs.columns.each do |col|
          h[col.table] ||= {} of String => DBAny
          h[col.table][col.name] = rs.read
          if h[col.table][col.name].is_a?(Int8)
            h[col.table][col.name] = h[col.table][col.name] == 1i8
          end
        end
        h
      end
    end
  end
end
