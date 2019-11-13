module Jennifer
  module Validations
    # Acceptance validation class.
    #
    # For more details see `Macros.validates_acceptance`.
    class Acceptance < Validator
      def validate(record, field : Symbol, value, _allow_blank : Bool, accept : Array? = nil)
        return true if value.nil?

        invalid =
          if accept.nil?
            value != true && value != "1" && value != "true"
          else
            !accept.not_nil!.includes?(value)
          end
        record.errors.add(field, :accepted) if invalid
      end
    end
  end
end
