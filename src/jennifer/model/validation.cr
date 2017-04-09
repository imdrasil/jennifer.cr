module Jennifer
  module Model
    module Validation
      include Accord

      def validate(skip = false)
      end

      macro validates_with_method(*names)
        {% for method in names %}
          {% VALIDATION_METHODS << method.stringify %}
        {% end %}
      end

      macro validates_with_method(name)
        {% VALIDATION_METHODS << name.stringify %}
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

      macro validate_inclucions(field, value)
        validates_with_method(%validate_method)

        def %validate_method
          unless ({{value}}).includes?(@{{field.id}})
            errors.add({{field}}, "should be in #{{{value}}} but is #{@{{field.id}}}")
          end
        end
      end

      macro validate_exclusion(field, value)
        validates_with_method(%validate_method)

        def %validate_method
          if ({{value}}).includes?(@{{field.id}})
            errors.add({{field}}, "should not be in #{value} but is #{@{{field.id}}}")
          end
        end
      end

      macro validate_format(field, value)
        validates_with_method(%validate_method)

        def %validate_method
          if {{value}} =~ (@{{field.id}})
            errors.add({{field}}, "should be like #{value} but is #{@{{field.id}}}")
          end
        end
      end

      macro validate_length(field, options)
        validates_with_method(%validate_method)

        def %validate_method
          {% if options[:in]? %}
            unless ({{options[:in]}}).includes?(@{{field.id}})
              errors.add({{field}}, "should be in #{value} but is #{@{{field.id}}}")
            end
          {% elsif options[:is]? %}
            if {{options[:is]}} != @{{field.id}}
              errors.add({{field}}, "should be #{value} but is #{@{{field.id}}}")
            end
          {% else %}
            {% if options[:minimum]? %}
              if {{options[:maximum]}} < @{{field.id}}
                errors.add({{field}}, "should be gte #{value} but is #{@{{field.id}}}")
              end
            {% end %}
            {% if options[:maximum]? %}
              if {{options[:minimum]}} > @{{field.id}}
                errors.add({{field}}, "should be lte #{value} but is #{@{{field.id}}}")
              end
            {% end %}
          {% end %}
        end
      end

      macro validate_uniqueness(field)
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
