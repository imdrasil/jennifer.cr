module Jennifer
  module Validations
    # Base validation class.
    #
    # Take into account that Validator implement singleton pattern. This means that
    # only one instance of each validator will be created cross the application. As a result #validate
    # method should be pure.
    #
    # To implement own validator just inherit and define #validate class, which accepts *record* as a first
    # argument
    #
    # ```
    # class CustomValidator < Jennifer::Validations::Validator
    #   def validate(record, field, message = nil)
    #     if record.attribute(field) == "invalid"
    #       record.errors.add(field, message || "blank")
    #     end
    #   end
    # end
    # ```
    abstract class Validator
      # :nodoc:
      module ClassMethods
        abstract def instance
      end

      extend ClassMethods

      # Validates given *record* based on *args* and *opts*.
      abstract def validate(record, **opts)

      def blank_validation(record, field, value, allow_blank)
        if allow_blank
          return if value.nil?
        elsif value.nil?
          record.errors.add(field, :blank)
          return false
        end
        true
      end

      macro with_blank_validation(record, field, value, allow_blank)
        case blank_validation({{record}}, {{field}}, {{value}}, {{allow_blank}})
        when false
          false
        when nil
          true
        else
          {{yield}}
        end
      end

      macro inherited
        {% unless @type.abstract? %}
          def self.instance
            @@instance ||= new
          end
        {% end %}
      end
    end
  end
end
