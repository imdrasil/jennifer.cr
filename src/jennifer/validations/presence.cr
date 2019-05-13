module Jennifer
  module Validations
    # Presence validation class.
    #
    # For more details see `Macros.validates_presence`.
    class Presence < Validator
      def validate(record, field : Symbol, value, _allow_blank : Bool)
        record.errors.add(field, :blank) if value.blank?
      end
    end
  end
end
