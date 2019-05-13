module Jennifer
  module Validations
    # Exclusion validation class.
    #
    # For more details see `Macros.validates_exclusion`.
    class Exclusion < Validator
      def validate(record, field : Symbol, value, allow_blank : Bool, collection)
        with_blank_validation do
          record.errors.add(field, :exclusion) if collection.includes?(value.not_nil!)
        end
      end
    end
  end
end
