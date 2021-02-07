module Jennifer
  module Validations
    # Exclusion validation class.
    #
    # For more details see `Macros.validates_exclusion`.
    class Exclusion < Validator
      def validate(record, **opts)
        field = opts[:field]
        value = opts[:value]
        allow_blank = opts[:allow_blank]
        with_blank_validation(record, field, value, allow_blank) do
          record.errors.add(field, :exclusion) if opts[:collection]?.not_nil!.includes?(value.not_nil!)
        end
      end
    end
  end
end
