module Jennifer
  module Validations
    # Presence validation class.
    #
    # For more details see `Macros.validates_presence`.
    class Presence < Validator
      def validate(record, **opts)
        record.errors.add(opts[:field], opts[:message]? || :blank) if opts[:value].blank?
      end
    end
  end
end
