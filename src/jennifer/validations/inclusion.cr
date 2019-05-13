module Jennifer
  module Validations
    # Inclusion validation class.
    #
    # For more details see `Macros.validates_inclusion`.
    class Inclusion < Validator
      def validate(record, field : Symbol, value, allow_blank : Bool, collection)
        with_blank_validation do
          record.errors.add(field, :inclusion) unless collection.includes?(value.not_nil!)
        end
      end
    end
  end
end
