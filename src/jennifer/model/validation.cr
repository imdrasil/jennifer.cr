require "../validations/static_validator"
require "../validations/*"

module Jennifer
  module Model
    module Validation
      def errors
        @errors ||= Errors.new(self)
      end

      def valid?
        validate!
      end

      def invalid?
        errors.any?
      end

      def validate(skip = false)
      end

      def validate!(skip = false) : Bool
        errors.clear
        return false if skip || !__before_validation_callback
        validate
        return false if invalid?
        __after_validation_callback
        true
      end

      # :nodoc:
      macro inherited_hook
        # :nodoc:
        VALIDATION_METHODS = [] of String
      end

      # :nodoc:
      macro finished_hook
        def validate(skip = false)
          return if skip
          super
          \{% for method in VALIDATION_METHODS %}
            \{{method.id}}
          \{% end %}
        end
      end

      # :nodoc:
      macro _not_nil_validation(field, allow_blank)
        begin
          res = ::Jennifer::Validations::StaticValidator.validate(self, {{field}}, {{field.id}}, {{allow_blank}})
          return res unless res
          {{field.id}}.not_nil!
        end
      end

      # Adds a validation method to the class.
      macro validates_with_method(*names, if if_value = nil)
        {% if if_value %}
          {% names.reduce(VALIDATION_METHODS) { |arr, method| arr << "#{method.id} if #{if_value.id}" } %}
        {% else %}
          {% names.reduce(VALIDATION_METHODS) { |arr, method| arr << method.id.stringify } %}
        {% end %}
      end

      # Passes the record off to an instance of the class specified and allows them to add errors based on more complex conditions.
      macro validates_with(klass, if if_value = nil, **options)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          {{klass}}.new(errors).validate(self{% if options %}, {{**options}} {% end %})
        end
      end

      # Validation whether the value of the specified attribute is included in the given enumerable object.
      macro validates_inclusion(field, in, allow_blank = false, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Inclusion.validate(self, {{field}}, {{field.id}}, {{allow_blank}}, {{in}})
        end
      end

      # Validates that the value of the specified attribute is not in the given enumerable object.
      macro validates_exclusion(field, in, allow_blank = false, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Exclusion.validate(self, {{field}}, {{field.id}}, {{allow_blank}}, {{in}})
        end
      end

      # Validates whether the value of the specified attribute *field* is of the correct form by matching it
      # against the regular expression *value*.
      macro validates_format(field, value, allow_blank = false, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Format.validate(self, {{field}}, {{field.id}}, {{allow_blank}}, {{value}})
        end
      end

      # Validates that the specified attribute matches the length restrictions supplied.
      #
      # Only one option can be used at a time:
      # - minimum
      # - maximum
      # - is
      # - in
      macro validates_length(field, if if_value = nil, **options)
        {% options[:allow_blank] = options[:allow_blank] == nil ? false : options[:allow_blank] %}
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Length.validate(self, {{field}}, {{field.id}}, {{**options}})
        end
      end

      # Validates whether the value of the specified attributes are unique across the system.
      #
      # Because this check is performed outside the database there is still a chance that duplicate values will be
      # inserted in two parallel transactions. To guarantee against this you should create a unique index on the field.
      # TODO: add scope
      macro validates_uniqueness(field, allow_blank = false, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Uniqueness.validate(self, {{field}}, {{field.id}}, {{allow_blank}}, self.class.where { _{{field.id}} == {{field.id}} })
        end
      end

      # Validates that the specified attributes are not blank.
      macro validates_presence(field, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Presence.validate(self, {{field}}, {{field.id}}, false)
        end
      end

      # Validates that the specified attribute is absent.
      macro validates_absence(field, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Absence.validate(self, {{field}}, {{field.id}}, true)
        end
      end

      # Validates whether the value of the specified attribute satisfies given comparison condition.
      #
      # Configuration options:
      # - greater_than
      # - greater_than_or_equal_to
      # - equal_to
      # - less_than
      # - less_than_or_equal_to
      # - odd
      # - even
      macro validates_numericality(field, if if_value = nil, **options)
        {% options[:allow_blank] = options[:allow_blank] == nil ? false : options[:allow_blank] %}
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Numericality.validate(self, {{field}}, {{field.id}}, **{{options}})
        end
      end

      # Encapsulates the pattern of wanting to validate the acceptance of a terms of service check box (or similar agreement)
      #
      # This check is performed only if *field* is not nil.
      macro validates_acceptance(field, accept = nil, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Acceptance.validate(self, {{field}}, {{field.id}}, false, {{accept}})
        end
      end

      # Encapsulates the pattern of wanting to validate a password or email address field with a confirmation.
      macro validates_confirmation(field, case_sensitive = true, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Confirmation.validate(self, {{field}}, {{field.id}}, false, {{field.id}}_confirmation, {{case_sensitive}})
        end
      end
    end
  end
end
