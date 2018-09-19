module Jennifer
  module Validations
    class Format < StaticValidator
      def self.validate(record, field : Symbol, value, allow_blank : Bool, format)
        with_blank_validation do
          record.errors.add(field, :invalid) unless format =~ value
        end
      end
    end
  end
end
