module Jennifer
  module Validations
    #
    # Validates that the given field(s) of a record are unique for this type.
    #
    class Uniqueness < Validator
      def validate(record, **opts)
        field = opts[:field]
        value = opts[:value]
        allow_blank = opts[:allow_blank]

        with_blank_validation(record, field, value, allow_blank) do
          _query = opts[:query]?.not_nil!.clone
          _query.where { primary != record.primary } unless record.new_record?

          record.errors.add(field, opts[:message]? || :taken) if _query.exists?
        end
      end
    end
  end
end
