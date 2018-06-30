module Jennifer
  module Model
    class ParameterConverter
      def parse(value : String, str_class : String)
        case str_class
        when /Array/
          to_array(value, str_class)
        when /String/
          to_s(value)
        when /Int16/
          to_i16(value)
        when /Int64/
          to_i64(value)
        when /Int/
          to_i(value)
        when /Float32/
          to_f32(value)
        when /Float/
          to_f(value)
        when /Bool/
          to_b(value)
        when /JSON/
          to_json(value)
        when /Time/
          to_time(value)
        when /Numeric/
          to_numeric(value)
        else
          raise ArgumentError.new
        end
      end

      def parse(value : Nil, str_class : String)
        nil
      end

      def to_pr32(value)
        to_i(value)
      end

      def to_pr64(value)
        to_i64(value)
      end

      def to_s(value)
        value
      end

      def to_i16(value)
        value.to_i16
      end

      def to_i64(value)
        value.to_i64
      end

      def to_i(value)
        value.to_i
      end

      def to_f(value)
        value.to_f
      end

      def to_f32(value)
        value.to_f32
      end

      def to_b(value)
        value == "true" || value == "1" || value == "t"
      end

      def to_json(value)
        JSON.parse(value)
      end

      def to_time(value)
        format = value =~ / / ? "%F %T" : "%F"
        Time.parse(value, format, Config.local_time_zone)
      end

      def to_numeric(value)
        value = value.strip
        raise ArgumentError.new unless value =~ /-{0,1}\d+(.\d+){0,1}/
        sign =
          if value[0] == '-'
            value = value[1..-1]
            0x4000
          else
            0i16
          end

        number = to_f(value)
        size = value.size
        weight = value.index('.') || -1
        if weight == -1
          int_part = value
          digits = integer_str_to_i16_array(int_part)
          PG::Numeric.build(digits.size.to_i16, (digits.size - 1).to_i16, sign, 0i16, digits)
        else
          int_part = value[0...weight]
          digits = integer_str_to_i16_array(int_part)
          int_digits_size = digits.size
          float_str_to_i16_array(value[(weight + 1)..-1], digits)
          PG::Numeric.build(digits.size.to_i16, (int_digits_size - 1).to_i16, sign, (value.size - weight - 1).to_i16, digits)
        end
      end

      def to_array(value, str_class)
        array = to_json(value).as_a
        case str_class
        when /Int32/
          array.map(&.as_i)
        when /Float32/
          array.map(&.as_f32)
        when /Float64/
          array.map(&.as_f)
        when /Int16/
          array.map(&.as_i.to_i16)
        when /Int64/
          array.map(&.as_i64)
        when /String/
          array.map(&.as_s)
        else
          raise ArgumentError.new
        end
      end

      private def integer_str_to_i16_array(value)
        array = [] of Int16
        weight = value.size
        first_part_size = weight % 4
        start_i = 0
        end_i = first_part_size == 0 ? 4 : first_part_size
        while true
          array << value[start_i...end_i].to_i16
          break if weight <= end_i
          start_i = end_i
          end_i += 4
        end
        array
      end

      def float_str_to_i16_array(value : String, array = [] of Int16)
        weight = value.size
        start_i = 0
        end_i = 4
        while true
          array << value[start_i...end_i].ljust(4, '0').to_i16
          break if weight <= end_i
          start_i = end_i
          end_i += 4
        end
        array.delete_at(-1) if array[-1] == 0i16
        array
      end
    end
  end
end
