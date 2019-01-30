require "./validator"
require "./*"

module Jennifer
  module Validations
    module Macros
      # Adds a validation method to the class.
      macro validates_with_method(*names, if if_value = nil)
        {% if if_value %}
          {% names.reduce(VALIDATION_METHODS) { |arr, method| arr << "#{method.id} if #{if_value.id}" } %}
        {% else %}
          {% names.reduce(VALIDATION_METHODS) { |arr, method| arr << method.id.stringify } %}
        {% end %}
      end

      # Passes the record off to an instance of the class specified and allows them to add errors based on more complex conditions.
      macro validates_with(klass, *args, if if_value = nil, **options)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          {{klass}}.instance.validate(self{% if args.size > 0 %}, {{*args}} {% end %}{% if options.size > 0 %}, {{**options}} {% end %})
        end
      end

      # Validate whether the value of the specified attribute is included in the given enumerable object.
      macro validates_inclusion(field, in, allow_blank = false, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Inclusion.instance.validate(self, {{field}}, {{field.id}}, {{allow_blank}}, {{in}})
        end
      end

      # Validates that the value of the specified attribute is not in the given enumerable object.
      macro validates_exclusion(field, in, allow_blank = false, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Exclusion.instance.validate(self, {{field}}, {{field.id}}, {{allow_blank}}, {{in}})
        end
      end

      # Validates whether the value of the specified attribute *field* is of the correct form by matching it
      # against the regular expression *value*.
      macro validates_format(field, value, allow_blank = false, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Format.instance.validate(self, {{field}}, {{field.id}}, {{allow_blank}}, {{value}})
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
          ::Jennifer::Validations::Length.instance.validate(self, {{field}}, {{field.id}}, {{**options}})
        end
      end

      # Validates whether the value of the specified attributes are unique across the system.
      #
      # Because this check is performed outside the database there is still a chance that duplicate values will be
      # inserted in two parallel transactions. To guarantee against this you should create a unique index on the field.
      # TODO: add scope
      macro validates_uniqueness(*fields, allow_blank allow_blank_value = false, if if_value = nil)
        # raise a compile time error if a uniqueness validator is specified
        # that does not define any properties
        {% raise "A uniqueness check requires at least one field" if fields.empty? %}

        validates_with_method(%validate_method, if: {{if_value}})

        # generate a query that fetches records based on the marked
        # properties of the current entity 
        # (e.g. ... WHERE id = <id> AND name = <name> AND config = <config> ...)
        {% normalized_fields = fields.map(&.id) %}

        {% fields_condition = normalized_fields.map { |field| ".where { _#{field} == #{field} }" }.join("") %}

        # builds a unique identifier for this set of properties
        # (e.g. for uniqueness properties `:a`, `:b` this results in `:a_b`)
        {% fields_identifier = normalized_fields.join("_") %}

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Uniqueness.instance.validate(
            self,
            :{{fields_identifier.id}},
            # pass on nil here to signal nil values in record
            {{normalized_fields}}.all?(&.nil?) ? nil : {{normalized_fields}},
            {{allow_blank_value}},
            self.class{{fields_condition.id}}
          )
        end # %validate_method
      end # validates_uniqueness

      # Validates that the specified attributes are not blank.
      macro validates_presence(field, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Presence.instance.validate(self, {{field}}, {{field.id}}, false)
        end
      end

      # Validates that the specified attribute is absent.
      macro validates_absence(field, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Absence.instance.validate(self, {{field}}, {{field.id}}, true)
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
          ::Jennifer::Validations::Numericality.instance.validate(self, {{field}}, {{field.id}}, {{**options}})
        end
      end

      # Encapsulates the pattern of wanting to validate the acceptance of a terms of service check
      # box (or similar agreement).
      #
      # This check is performed only if *field* is not nil.
      macro validates_acceptance(field, accept = nil, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Acceptance.instance.validate(self, {{field}}, {{field.id}}, false, {{accept}})
        end
      end

      # Encapsulates the pattern of wanting to validate a password or email address field with a confirmation.
      macro validates_confirmation(field, case_sensitive = true, if if_value = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Confirmation.instance.validate(
            self,
            {{field}},
            {{field.id}},
            false,
            {{field.id}}_confirmation,
            {{case_sensitive}}
          )
        end
      end
    end
  end
end
