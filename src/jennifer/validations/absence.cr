module Jennifer
  module Validations
    class Absence < StaticValidator
      def self.validate(record, field : Symbol, value, _allow_blank : Bool)
        record.errors.add(field, :present) if value.present?
      end
    end
  end
end
