module Jennifer
  module Validations
    # Acceptance validation class.
    #
    # For more details see `Macros.validates_acceptance`.
    class Acceptance < Validator
      def validate(record, **opts)
        value = opts[:value]
        accept = opts[:accept]?

        return true if value.nil?

        invalid =
          if accept.nil?
            value != true && value != "1" && value != "true"
          else
            !accept.not_nil!.includes?(value)
          end
        record.errors.add(opts[:field], opts[:message]? || :accepted) if invalid
      end
    end
  end
end
