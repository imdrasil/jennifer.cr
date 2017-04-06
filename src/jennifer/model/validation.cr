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
    end
  end
end
