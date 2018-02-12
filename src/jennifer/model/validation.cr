module Jennifer
  module Model
    module Validation
      include Accord

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
            return errors.add({{field}}, self.class.human_error({{field}}, :blank)) if @{{field.id}}.nil?
          {% end %}
          @{{field.id}}.not_nil!
        end
      end

      macro validates_inclucion(field, value, allow_blank = false)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{allow_blank}})
          unless ({{value}}).includes?(value)
            errors.add({{field}}, self.class.human_error({{field}}, :inclusion))
          end
        end
      end

      macro validates_exclusion(field, value, allow_blank = false)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{allow_blank}})
          if ({{value}}).includes?(value)
            errors.add(:{{field.id}}, self.class.human_error({{field}}, :exclusion))
          end
        end
      end

      macro validates_format(field, value, allow_blank = false)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{allow_blank}})
          unless {{value}} =~ value
            errors.add({{field}}, self.class.human_error({{field}}, :invalid))
          end
        end
      end

      macro validates_length(field, **options)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{options[:allow_blank] || false}})
          size = value.not_nil!.size
          {% if options[:in] %}
            if ({{options[:in]}}).max < size
              errors.add({{field}}, self.class.human_error({{field}}, :too_long, ({{options[:in]}}).max))
            elsif ({{options[:in]}}).min > size
              errors.add({{field}}, self.class.human_error({{field}}, :too_short, ({{options[:in]}}).min))
            end
          {% elsif options[:is] %}
            if {{options[:is]}} != size
              errors.add({{field}}, self.class.human_error({{field}}, :wrong_length, {{options[:is]}}))
            end
          {% elsif options[:minimum] %}
            if {{options[:minimum]}} > size
              errors.add({{field}}, self.class.human_error({{field}}, :too_short, {{options[:minimum]}}))
            end
          {% elsif options[:maximum] %}
            if {{options[:maximum]}} < size
              errors.add({{field}}, self.class.human_error({{field}}, :too_long, {{options[:maximum]}}))
            end
          {% end %}
        end
      end

      macro validates_uniqueness(field)
        validates_with_method(%validate_method)

        def %validate_method
          value = @{{field.id}}
          if self.class.where { _{{field.id}} == value }.exists?
            errors.add({{field}}, self.class.human_error({{field}}, :taken))
          end
        end
      end

      # Validates field to not be nil
      macro validates_presence_of(field)
        validates_with_method(%validate_method)

        def %validate_method
          value = @{{field.id}}
          if value.nil?
            errors.add({{field}}, self.class.human_error({{field}}, :presence))
          end
        end
      end

      macro validates_numericality(field, **options)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{options[:allow_blank] || false}})
          {% if options[:greater_than] %}
            if {{options[:greater_than]}} >= value 
              errors.add({{field}}, self.class.human_error({{field}}, :greater_than, { :value => {{options[:greater_than]}} }))
            end
          {% end %}
          {% if options[:greater_than_or_equal_to] %}
            if {{options[:greater_than_or_equal_to]}} > value
              errors.add({{field}}, self.class.human_error({{field}}, :greater_than_or_equal_to, { :value => {{options[:greater_than_or_equal_to]}} }))
            end
          {% end %}
          {% if options[:equal_to] %}
            if {{options[:equal_to]}} != value
              errors.add({{field}}, self.class.human_error({{field}}, :equal_to, { :value => {{options[:equal_to]}} }))
            end
          {% end %}
          {% if options[:less_than] %}
            if {{options[:less_than]}} <= value
              errors.add({{field}}, self.class.human_error({{field}}, :less_than, { :value => {{options[:less_than]}} }))
            end
          {% end %}
          {% if options[:less_than_or_equal_to] %}
            if {{options[:less_than_or_equal_to]}} < value
              errors.add({{field}}, self.class.human_error({{field}}, :less_than_or_equal_to, { :value => {{options[:less_than_or_equal_to]}} }))
            end
          {% end %}
          {% if options[:other_than] %}
            if {{options[:other_than]}} == value
              errors.add({{field}}, self.class.human_error({{field}}, :other_than, { :value => {{options[:other_than]}} }))
            end
          {% end %}
          {% if options[:odd] %}
            if value.even?
              errors.add({{field}}, self.class.human_error({{field}}, :odd))
            end
          {% end %}
          {% if options[:even] %}
            if value.odd?
              errors.add({{field}}, self.class.human_error({{field}}, :even))
            end
          {% end %}
        end
      end
    end
  end
end
