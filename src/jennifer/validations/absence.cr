module Jennifer
  module Validations
    # Absence validation class.
    #
    # For more details see `Macros.validates_absence`.
    class Absence < Validator
      def validate(record, **opts)
        record.errors.add(opts[:field], opts[:message]? || :present) if opts[:value].present?
      end
    end
  end
end
