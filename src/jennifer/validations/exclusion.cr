module Jennifer
  module Validations
    class Exclusion < StaticValidator
      def self.validate(record, field : Symbol, value, allow_blank : Bool, collection)
        with_blank_validation do
          record.errors.add(field, :exclusion) if collection.includes?(value.not_nil!)
        end
      end
    end
  end
end
