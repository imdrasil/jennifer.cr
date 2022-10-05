module Jennifer
  module Validations
    # Text format validation class.
    #
    # For more details see `Macros.validates_format`.
    class Format < Validator
      def validate(record, **opts)
        field = opts[:field]
        value = opts[:value]
        allow_blank = opts[:allow_blank]
        with_blank_validation(record, field, value, allow_blank) do
          record.errors.add(field, opts[:message]? || :invalid) unless opts[:format]?.not_nil! =~ value
        end
      end
    end
  end
end
