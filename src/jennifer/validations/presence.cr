module Jennifer
  module Validations
    class Presence < StaticValidator
      def self.validate(record, field : Symbol, value, _allow_blank : Bool)
        record.errors.add(field, :blank) if value.blank?
      end
    end
  end
end
