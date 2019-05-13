module Jennifer
  module Validations
    # Absence validation class.
    #
    # For more details see `Macros.validates_absence`.
    class Absence < Validator
      def validate(record, field, value, allow_blank)
        record.errors.add(field, :present) if value.present?
      end
    end
  end
end
