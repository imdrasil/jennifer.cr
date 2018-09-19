module Jennifer
  module Validations
    class Uniqueness < StaticValidator
      def self.validate(record, field : Symbol, value, allow_blank : Bool, query)
        with_blank_validation do
          query = query.where { primary != record.primary } unless record.new_record?

          record.errors.add(field, :taken) if query.exists?
        end
      end
    end
  end
end
