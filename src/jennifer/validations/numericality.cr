module Jennifer
  module Validations
    class Numericality < Validator
      def validate(record, field : Symbol, value, allow_blank : Bool, greater_than = nil, greater_than_or_equal_to = nil, equal_to = nil,
                        less_than = nil, less_than_or_equal_to = nil, other_than = nil, odd = nil, even = nil)
        with_blank_validation do
          value = value.not_nil!
          errors = record.errors

          errors.add(field, :greater_than, { :value => greater_than }) if greater_than.try(&.>= value)

          if greater_than_or_equal_to.try(&.> value)
            errors.add(field, :greater_than_or_equal_to, { :value => greater_than_or_equal_to })
          end

          errors.add(field, :equal_to, { :value => equal_to }) if equal_to.try(&.!= value)

          errors.add(field, :less_than, { :value => less_than }) if less_than.try(&.<= value)

          if less_than_or_equal_to.try(&.< value)
            errors.add(field, :less_than_or_equal_to, { :value => less_than_or_equal_to })
          end

          errors.add(field, :other_than, { :value => other_than }) if other_than.try(&.== value)

          errors.add(field, :odd) if odd && value.even?

          errors.add(field, :even) if even && value.odd?
        end
      end
    end
  end
end
