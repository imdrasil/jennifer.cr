module Jennifer
  module Validations
    # Confirmation validation class.
    #
    # For more details see `Macros.validates_confirmation`.
    class Confirmation < Validator
      def validate(record, **opts)
        field = opts[:field]
        confirmation = opts[:confirmation]?

        return true if confirmation.nil?

        value = opts[:value]
        with_blank_validation(record, field, value, false) do
          return true if value.not_nil!.compare(confirmation.not_nil!, !opts[:case_sensitive]?.not_nil!) == 0

          record.errors.add(
            field,
            opts[:message]? || :confirmation,
            options: {:attribute => record.class.human_attribute_name(field)}
          )
        end
      end
    end
  end
end
