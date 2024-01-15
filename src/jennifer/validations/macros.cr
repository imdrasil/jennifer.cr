require "./validator"
require "./*"

module Jennifer
  module Validations
    module Macros
      # Adds a validation method to the class.
      #
      # ```
      # class User < Jennifer::Model::Base
      #   # ...
      #
      #   validates_with_method :thirteen
      #
      #   def thirteen
      #     errors.add(:id, "Can't be 13") if id == 13
      #   end
      # end
      # ```
      macro validates_with_method(*names, if if_value = nil)
        {% if if_value %}
          {% names.reduce(VALIDATION_METHODS) { |arr, method| arr << "#{method.id} if #{if_value.id}" } %}
        {% else %}
          {% names.reduce(VALIDATION_METHODS) { |arr, method| arr << method.id.stringify } %}
        {% end %}
      end

      # Passes the record off to an instance of the class specified and allows them to add errors based on more complex conditions.
      #
      # ```
      # class EnnValidator < Jennifer::Validations::Validator
      #   def validate(record : Passport)
      #     record.errors.add(:enn, "Invalid enn") if record.enn!.size < 4
      #   end
      # end
      #
      # class Passport < Jennifer::Model::Base
      #   mapping(
      #     enn: {type: String, primary: true}
      #   )
      #
      #   validates_with EnnValidator
      # end
      # ```
      macro validates_with(klass, *args, if if_value = nil, **options)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          {{klass}}.instance
            .validate(self{% if args.size > 0 %}, {{*args}} {% end %}{% if options.size > 0 %}, {{options.double_splat}} {% end %})
        end
      end

      # Validate whether the value of the specified attribute is included in the given enumerable object.
      #
      # ```
      # class User < Jennifer::Base::Model
      #   mapping(
      #     # ...
      #     country_code: String
      #   )
      #
      #   validates_inclusion :code, in: Country::KNOWN_COUNTRIES
      # end
      # ```
      macro validates_inclusion(field, in in_value, allow_blank = false, if if_value = nil, message = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Inclusion.instance.validate(
            self,
            field: {{field}},
            value: {{field.id}},
            allow_blank: {{allow_blank}},
            collection: {{in_value}},
            message: {{message}}
          )
        end
      end

      # Validates that the value of the specified attribute is not in the given enumerable object.
      #
      # ```
      # class Country < Jennifer::Base::Model
      #   mapping(
      #     # ...
      #     code: String
      #   )
      #
      #   validates_exclusion :code, in: %w(AA DD)
      # end
      # ```
      macro validates_exclusion(field, in in_value, allow_blank = false, if if_value = nil, message = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Exclusion.instance.validate(
            self,
            field: {{field}},
            value: {{field.id}},
            allow_blank: {{allow_blank}},
            collection: {{in_value}},
            message: {{message}}
          )
        end
      end

      # Validates whether the value of the specified attribute *field* is of the correct form by matching it
      # against the regular expression *value*.
      #
      # ```
      # class Contact < Jennifer::Model::Base
      #   mapping(
      #     # ...
      #     street: String
      #   )
      #
      #   validates_format :street, /st\.|street/i
      # end
      # ```
      macro validates_format(field, value, allow_blank = false, if if_value = nil, message = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Format.instance.validate(
            self,
            field: {{field}},
            value: {{field.id}},
            allow_blank: {{allow_blank}},
            format: {{value}},
            message: {{message}}
          )
        end
      end

      # Validates that the specified attribute matches the length restrictions supplied.
      #
      # Only one option can be used at a time:
      # - minimum
      # - maximum
      # - is
      # - in
      #
      # ```
      # class User < Jennifer::Model::Base
      #   mapping( # ...
      # )
      #
      #   validates_length :name, minimum: 2
      #   validates_length :login, in: 4..16
      #   validates_length :uid, is: 16
      # end
      # ```
      macro validates_length(field, if if_value = nil, message = nil, **options)
        {% options[:allow_blank] = options[:allow_blank] == nil ? false : options[:allow_blank] %}
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Length.instance.validate(
            self,
            field: {{field}},
            value: {{field.id}},
            message: {{message}},
            {{options.double_splat}}
          )
        end
      end

      # Validates whether the value of the specified attributes are unique across the system.
      #
      # Because this check is performed outside the database there is still a chance that duplicate values will be
      # inserted in two parallel transactions. To guarantee against this you should create a unique index on the field.
      #
      # ```
      # class Country < Jennifer::Model::Base
      #   mapping(
      #     # ...
      #     code: String
      #   )
      #
      #   validate_uniqueness :code
      # end
      # ```
      macro validates_uniqueness(*fields, allow_blank allow_blank_value = false, if if_value = nil, message = nil)
        # raise a compile time error if a uniqueness validator is specified
        # that does not define any properties
        {% raise "A uniqueness check requires at least one field" if fields.empty? %}

        validates_with_method(%validate_method, if: {{if_value}})

        # generate a query that fetches records based on the marked
        # properties of the current entity
        # (e.g. ... WHERE id = <id> AND name = <name> AND config = <config> ...)
        {% normalized_fields = fields.map(&.id) %}

        {% fields_condition = normalized_fields.map { |field| ".where { self.class._#{field} == #{field} }" }.join("") %}

        # builds a unique identifier for this set of properties
        # (e.g. for uniqueness properties `:a`, `:b` this results in `:a_b`)
        {% fields_identifier = normalized_fields.join("_") %}

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Uniqueness.instance.validate(
            self,
            field: :{{fields_identifier.id}},
            # pass on nil here to signal nil values in record
            value: {{normalized_fields}}.all?(&.nil?) ? nil : {{normalized_fields}},
            allow_blank: {{allow_blank_value}},
            message: {{message}},
            query: self.class{{fields_condition.id}}
          )
        end
      end

      # Validates that the specified attributes are not blank.
      #
      # ```
      # class User < Jennifer::Model::Base
      #   mapping(
      #     # ...
      #     email: String?
      #   )
      #
      #   validates_presence :email
      # end
      # ```
      macro validates_presence(field, if if_value = nil, message = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Presence.instance.validate(
            self,
            field: {{field}},
            value: {{field.id}},
            message: {{message}}
          )
        end
      end

      # Validates that the specified attribute is absent.
      #
      # ```
      # class Article < Jennifer::Model::Base
      #   mapping( # ...
      # )
      #
      #   validates_absence :title
      # end
      # ```
      macro validates_absence(field, if if_value = nil, message = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Absence.instance.validate(
            self,
            field: {{field}},
            value: {{field.id}},
            message: {{message}}
          )
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
      #
      # ```
      # class Player < Jennifer::Model::Base
      #   mapping(
      #     # ...
      #     health: Float64,
      #   )
      #
      #   validates_numericality :health, greater_than: 0
      # end
      # ```
      macro validates_numericality(field, if if_value = nil, message = nil, **options)
        {% options[:allow_blank] = options[:allow_blank] == nil ? false : options[:allow_blank] %}
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Numericality.instance.validate(
            self,
            field: {{field}},
            value: {{field.id}},
            message: {{message}},
            {{options.double_splat}}
          )
        end
      end

      # Encapsulates the pattern of wanting to validate the acceptance of a terms of service check
      # box (or similar agreement).
      #
      # This check is performed only if *field* is not nil.
      #
      # ```
      # class User < Jennifer::Model::Base
      #   mapping( # ...
      # )
      #
      #   property terms_of_service = false
      #   property eula : String?
      #
      #   validates_acceptance :terms_of_service
      #   validates_acceptance :eula, accept: %w(true accept yes)
      # end
      # ```
      macro validates_acceptance(field, accept = nil, if if_value = nil, message = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Acceptance.instance.validate(
            self,
            field: {{field}},
            value: {{field.id}},
            accept: {{accept}},
            message: {{message}}
          )
        end
      end

      # Encapsulates the pattern of wanting to validate a password or email address field with a confirmation.
      #
      # ```
      # class User < Jennifer::Model::Base
      #   mapping(
      #     # ...
      #     email: String?,
      #     address: String?
      #   )
      #
      #   property email_confirmation : String?, address_confirmation : String?
      #
      #   validates_confirmation :email
      #   validates_confirmation :address, case_insensitive: true
      # end
      # ```
      macro validates_confirmation(field, case_sensitive = true, if if_value = nil, message = nil)
        validates_with_method(%validate_method, if: {{if_value}})

        # :nodoc:
        def %validate_method
          ::Jennifer::Validations::Confirmation.instance.validate(
            self,
            field: {{field}},
            value: {{field.id}},
            confirmation: {{field.id}}_confirmation,
            case_sensitive: {{case_sensitive}},
            message: {{message}}
          )
        end
      end
    end
  end
end
