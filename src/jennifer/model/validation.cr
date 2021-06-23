require "../validations/macros"

module Jennifer
  module Model
    module Validation
      include Validations::Macros

      @[JSON::Field(ignore: true)]
      @errors : Errors?

      # Returns container with object's validation errors.
      def errors : Errors
        @errors ||= Errors.new(self)
      end

      # Returns whether object is valid.
      #
      # Each invocation of this method triggers validations from scratch. If you want to avoid this -
      # use `#invalid?`.
      #
      # ```
      # User.new({age: -2}).valid?
      # ```
      def valid?
        validate!
      end

      # Returns whether `#errors` container has any error.
      #
      # Doesn't trigger validation.
      def invalid?
        !errors.empty?
      end

      # :nodoc:
      def validate(skip = false)
      end

      # Invokes validation and callbacks.
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
        # :nodoc:
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
