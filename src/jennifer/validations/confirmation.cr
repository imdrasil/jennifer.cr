module Jennifer
  module Validations
    class Confirmation < Validator
      def validate(record, field : Symbol, value, allow_blank : Bool, confirmation, case_sensitive)
        return true if confirmation.nil?
        with_blank_validation do
          return true if value.not_nil!.compare(confirmation.not_nil!, !case_sensitive) == 0
          record.errors.add(
            field,
            :confirmation,
            options: { :attribute => record.class.human_attribute_name(field) }
          )
        end
      end
    end
  end
end
