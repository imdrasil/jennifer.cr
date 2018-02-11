require "./validation_messages"

module Jennifer
  module Model
    module Validation
      include Accord
      include ValidationMessages

      def validate(skip = false)
      end

      # TODO: invoke validation callbacks
      def validate!(skip = false)
        errors.clear!
        return if skip

        # TODO: think about global validation
        if self.responds_to?(:validate_global)
          self.validate_global
        end
        if self.responds_to?(:validate)
          self.validate
        end
      end

      macro validates_with_method(name)
        {% VALIDATION_METHODS << name.id.stringify %}
      end

      macro validates_with_method(*names)
        {% for method in names %}
          {% VALIDATION_METHODS << method.id.stringify %}
        {% end %}
      end

      macro inherited_hook
        VALIDATION_METHODS = [] of String
      end

      macro finished_hook
        def validate(skip = false)
          return if skip
          super
          \{% for method in VALIDATION_METHODS %}
            \{{method.id}}
          \{% end %}
        end
      end

      macro _not_nil_validation(field, allow_blank)
        begin
          {% if allow_blank %}
            return if @{{field.id}}.nil?
          {% else %}
            return errors.add({{field}}, not_blank_message) if @{{field.id}}.nil?
          {% end %}
          @{{field.id}}.not_nil!
        end
      end

      macro validates_inclucion(field, value, allow_blank = false)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{allow_blank}})
          unless ({{value}}).includes?(value)
            errors.add({{field}}, must_be_message({{value}}, value))
          end
        end
      end

      macro validates_exclusion(field, value, allow_blank = false)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{allow_blank}})
          if ({{value}}).includes?(value)
            errors.add(:{{field.id}}, must_not_be_message({{value}}, value))
          end
        end
      end

      macro validates_format(field, value, allow_blank = false)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{allow_blank}})
          unless {{value}} =~ value
            errors.add({{field}}, must_be_like_message({{value}}, value))
          end
        end
      end

      macro validates_length(field, **options)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{options[:allow_blank] || false}})
          size = value.not_nil!.size
          {% if options[:in] %}
            unless ({{options[:in]}}).includes?(size)
              errors.add({{field}}, length_in_message({{options[:in]}}, size))
            end
          {% elsif options[:is] %}
            if {{options[:is]}} != size
              errors.add({{field}}, length_is_message({{options[:is]}}, size))
            end
          {% else %}
            {% if options[:minimum] %}
              if {{options[:minimum]}} > size
                errors.add({{field}}, length_min_message({{options[:minimum]}}, size))
              end
            {% end %}
            {% if options[:maximum] %}
              if {{options[:maximum]}} < size
                errors.add({{field}}, length_max_message({{options[:maximum]}}, size))
              end
            {% end %}
          {% end %}
        end
      end

      macro validates_uniqueness(field)
        validates_with_method(%validate_method)

        def %validate_method
          value = @{{field.id}}
          if self.class.where { _{{field.id}} == value }.exists?
            errors.add({{field}}, must_be_unique_message(value))
          end
        end
      end

      # Validates field to not be nil
      macro validates_presence_of(field)
        validates_with_method(%validate_method)

        def %validate_method
          value = @{{field.id}}
          if value.nil?
            errors.add({{field}}, not_blank_message)
          end
        end
      end
    end
  end
end
