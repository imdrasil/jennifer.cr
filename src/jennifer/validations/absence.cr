module Jennifer
  module Validations
    class Absence < Validator
      def validate(record, field, value, allow_blank)
        record.errors.add(field, :present) if value.present?
      end
    end
  end
end
