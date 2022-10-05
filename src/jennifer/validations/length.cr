module Jennifer
  module Validations
    # Length validation class.
    #
    # For more details see `Macros.validates_length`.
    class Length < Validator
      def validate(record, **opts) # ameba:disable Metrics/CyclomaticComplexity
        field = opts[:field]
        value = opts[:value]
        allow_blank = opts[:allow_blank]
        in_value = opts[:in]?
        is = opts[:is]?
        minimum = opts[:minimum]?
        maximum = opts[:maximum]?

        with_blank_validation(record, field, value, allow_blank) do
          size = value.not_nil!.size
          errors = record.errors
          if in_value
            if in_value.max < size
              errors.add(field, opts[:message]? || :too_long, in_value.max)
            elsif in_value.min > size
              errors.add(field, opts[:message]? || :too_short, in_value.min)
            end
          elsif is && is != size
            errors.add(field, opts[:message]? || :wrong_length, is)
          elsif minimum && minimum > size
            errors.add(field, opts[:message]? || :too_short, minimum)
          elsif maximum && maximum < size
            errors.add(field, opts[:message]? || :too_long, maximum)
          end
        end
      end
    end
  end
end
