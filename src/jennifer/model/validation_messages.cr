module Jennifer
  module Model
    module ValidationMessages
      def must_be_message(expected, actual)
        "must be in #{expected} but is #{actual}"
      end

      def must_not_be_message(expected, actual)
        "must not be in #{expected} but is #{actual}"
      end

      def not_blank_message
        "must not be blank"
      end

      def length_in_message(expected, actual)
        "must be of size #{expected} but has #{actual}"
      end

      def length_is_message(expected, actual)
        "must be of size#{expected} but has #{actual}"
      end

      def length_min_message(expected, actual)
        "must be greater than or equal #{expected} but is #{actual}"
      end

      def length_max_message(expected, actual)
        "must be less than or equal #{expected} but is #{actual}"
      end

      def must_be_like_message(expected, actual)
        "must be like #{expected} but is #{actual}"
      end

      def must_be_unique_message(value)
        "must be unique"
      end
    end
  end
end
