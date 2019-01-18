module Jennifer
  module Validations
    class Uniqueness < Validator
      def validate(record, field : Symbol, value, allow_blank : Bool, query)
        with_blank_validation do
          _query = query.clone
          _query.where { primary != record.primary } unless record.new_record?

          record.errors.add(field, :taken) if _query.exists?
        end
      end
    end

    #
    # Validates that a combination of fields of a given record
    # are unique for this type.
    #
    class CompositeUniqueness < Validator
      def validate(record, query, fields)
        _query = query.clone
        _query.where { primary != record.primary } unless record.new_record?

        fields.each do |field|
          record.errors.add(field, :combination_taken) if _query.exists?
        end
      end # validate
    end # CompositeUniqueness
  end
end
