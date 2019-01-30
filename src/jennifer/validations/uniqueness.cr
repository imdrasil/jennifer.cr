module Jennifer
  module Validations
    #
    # Validates that the given field(s) of a record are unique for this type.
    #
    class Uniqueness < Validator
      def validate(record, field : Symbol, value, allow_blank : Bool, query)
        with_blank_validation do
          _query = query.clone
          _query.where { primary != record.primary } unless record.new_record?

          record.errors.add(field, :taken) if _query.exists?
        end
      end # validate
    end # Uniqueness

  end # Validations
end # Jennifer
