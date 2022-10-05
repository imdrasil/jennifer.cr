module Jennifer
  module Validations
    # Inclusion validation class.
    #
    # For more details see `Macros.validates_inclusion`.
    class Inclusion < Validator
      def validate(record, **opts)
        field = opts[:field]
        value = opts[:value]
        allow_blank = opts[:allow_blank]
        with_blank_validation(record, field, value, allow_blank) do
          unless opts[:collection]?.not_nil!.includes?(value.not_nil!)
            record.errors.add(field, opts[:message]? || :inclusion)
          end
        end
      end
    end
  end
end
