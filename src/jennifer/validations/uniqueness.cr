module Jennifer
  module Validations
    class Uniqueness < Validator
      def validate(record, field : Symbol, value, allow_blank : Bool, query)
        with_blank_validation do
          _query = query.clone
          _query = query.where { primary != record.primary } unless record.new_record?

          record.errors.add(field, :taken) if _query.exists?
        end
      end
    end
  end
end
