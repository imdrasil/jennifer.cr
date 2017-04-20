module Jennifer
  module Model
    module Validation
      include Accord

      def validate(skip = false)
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

      macro validates_inclucion(field, value)
        validates_with_method(%validate_method)

        def %validate_method
          unless ({{value}}).includes?(@{{field.id}})
            errors.add({{field}}, "should be in #{{{value}}} but is #{@{{field.id}}}")
          end
        end
      end

      macro validates_exclusion(field, value)
        validates_with_method(%validate_method)

        def %validate_method
          if ({{value}}).includes?(@{{field.id}})
            errors.add(:{{field.id}}, "should not be in #{{{value}}} but is #{@{{field.id}}}")
          end
        end
      end

      macro validates_format(field, value)
        validates_with_method(%validate_method)

        def %validate_method
          unless {{value}} =~ @{{field.id}}.not_nil!
            errors.add({{field}}, "should be like #{{{value}}} but is #{@{{field.id}}}")
          end
        end
      end

      macro validates_length(field, **options)
        validates_with_method(%validate_method)

        def %validate_method
          size = @{{field.id}}.not_nil!.size
          {% if options[:in] %}
            unless ({{options[:in]}}).includes?(size)
              errors.add({{field}}, "should be in #{{{options[:in]}}} but is #{@{{field.id}}}")
            end
          {% elsif options[:is] %}
            if {{options[:is]}} != size
              errors.add({{field}}, "should be #{{{options[:is]}}} but is #{@{{field.id}}}")
            end
          {% else %}
            {% if options[:minimum] %}
              if {{options[:minimum]}} > size
                errors.add({{field}}, "should be gte #{{{options[:minimum]}}} but is #{@{{field.id}}}")
              end
            {% end %}
            {% if options[:maximum] %}
              if {{options[:maximum]}} < size
                errors.add({{field}}, "should be lte #{{{options[:maximum]}}} but is #{@{{field.id}}}")
              end
            {% end %}
          {% end %}
        end
      end

      macro validates_uniqueness(field)
        validates_with_method(%validate_method)

        def %validate_method
          value = @{{field.id}}
          if {{@type}}.where { _{{field.id}} == value }.exists?
            errors.add({{field}}, "should be unique")
          end
        end
      end
    end
  end
end
