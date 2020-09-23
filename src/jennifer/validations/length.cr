module Jennifer
  module Validations
    # Length validation class.
    #
    # For more details see `Macros.validates_length`.
    class Length < Validator
      def validate(record, field : Symbol, value, allow_blank : Bool, in in_value = nil, is = nil, minimum = nil, maximum = nil)
        with_blank_validation do
          size = value.not_nil!.size
          errors = record.errors
          if in_value
            if in_value.max < size
              errors.add(field, :too_long, in_value.max)
            elsif in_value.min > size
              errors.add(field, :too_short, in_value.min)
            end
          elsif is && is != size
            errors.add(field, :wrong_length, is)
          elsif minimum && minimum > size
            errors.add(field, :too_short, minimum)
          elsif maximum && maximum < size
            errors.add(field, :too_long, maximum)
          end
        end
      end
    end
  end
end
