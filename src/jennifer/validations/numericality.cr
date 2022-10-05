module Jennifer
  module Validations
    # Numericality validation class.
    #
    # For more details see `Macros.validates_numericality`.
    class Numericality < Validator
      def validate(record, **opts) # ameba:disable Metrics/CyclomaticComplexity
        field = opts[:field]
        value = opts[:value]
        allow_blank = opts[:allow_blank]
        greater_than = opts[:greater_than]?
        greater_than_or_equal_to = opts[:greater_than_or_equal_to]?
        equal_to = opts[:equal_to]?
        less_than = opts[:less_than]?
        less_than_or_equal_to = opts[:less_than_or_equal_to]?
        other_than = opts[:other_than]?
        odd = opts[:odd]?
        even = opts[:even]?

        with_blank_validation(record, field, value, allow_blank) do
          value = value.not_nil!
          errors = record.errors

          errors.add(field, opts[:message]? || :greater_than, {:value => greater_than}) if greater_than.try(&.>= value)

          if greater_than_or_equal_to.try(&.> value)
            errors.add(field, opts[:message]? || :greater_than_or_equal_to, {:value => greater_than_or_equal_to})
          end

          errors.add(field, opts[:message]? || :equal_to, {:value => equal_to}) if equal_to.try(&.!= value)

          errors.add(field, opts[:message]? || :less_than, {:value => less_than}) if less_than.try(&.<= value)

          if less_than_or_equal_to.try(&.< value)
            errors.add(field, opts[:message]? || :less_than_or_equal_to, {:value => less_than_or_equal_to})
          end

          errors.add(field, opts[:message]? || :other_than, {:value => other_than}) if other_than.try(&.== value)

          errors.add(field, opts[:message]? || :odd) if odd && even?(value)

          errors.add(field, opts[:message]? || :even) if even && odd?(value)
        end
      end

      private def odd?(value : Int)
        value.odd?
      end

      private def even?(value : Int | Float)
        !odd?(value)
      end

      private def odd?(value : Float64)
        odd?(value.to_i64)
      end

      private def odd?(value : Float32)
        odd?(value.to_i)
      end

      private def odd?(value : Nil)
      end

      private def even?(value : Nil)
      end

      private def odd?(value)
        raise ArgumentError.new("'#{value.inspect}' doesn't support :even validation")
      end

      private def even?(value)
        raise ArgumentError.new("'#{value.inspect}' doesn't support :odd validation")
      end
    end
  end
end
