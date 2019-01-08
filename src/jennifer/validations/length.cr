module Jennifer
  module Validations
    class Length < Validator
      def validate(record, field : Symbol, value, allow_blank : Bool, in = nil, is = nil, minimum = nil, maximum = nil)
        with_blank_validation do
          size = value.not_nil!.size
          errors = record.errors
          if in
            if in.max < size
              errors.add(field, :too_long, in.max)
            elsif in.min > size
              errors.add(field, :too_short, in.min)
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
