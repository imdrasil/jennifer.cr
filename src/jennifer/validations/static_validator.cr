module Jennifer
  module Validations
    class StaticValidator
      # :nodoc:
      macro with_blank_validation
        case blank_validation(record, field, value, allow_blank)
        when false
          false
        when nil
          true
        else
          {{yield}}
        end
      end

      def self.blank_validation(record, field : Symbol, value, allow_blank : Bool)
        if allow_blank
          return if value.nil?
        elsif value.nil?
          record.errors.add(field, :blank)
          return false
        end
        true
      end
    end
  end
end
