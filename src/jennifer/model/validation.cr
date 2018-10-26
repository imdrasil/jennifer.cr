require "../validations/macros"

module Jennifer
  module Model
    module Validation
      include Validations::Macros

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
    end
  end
end
