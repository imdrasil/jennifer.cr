module Jennifer
  module Model
    module Validation
      def errors
        @errors ||= Accord::ErrorList.new
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
        errors.clear!
        return false if skip
        return false unless __before_validation_callback
        validate
        return false if invalid?
        __after_validation_callback
        true
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

      macro validates_with_method(name)
        {% VALIDATION_METHODS << name.id.stringify %}
      end

      macro validates_with_method(*names)
        {% for method in names %}
          {% VALIDATION_METHODS << method.id.stringify %}
        {% end %}
      end

      macro validates_with(klass, **options)
        validates_with_method(%validate_method)

        def %validate_method
          {% if options %}
            {{klass}}.new(errors).validate(self, {{**options}})
          {% else %}
            {{klass}}.new(errors).validate(self)
          {% end %}
        end
      end

      macro validates_inclusion(field, in, allow_blank = false)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{allow_blank}})
          unless ({{in}}).includes?(value)
            errors.add({{field}}, self.class.human_error({{field}}, :inclusion))
          end
        end
      end

      macro validates_exclusion(field, in, allow_blank = false)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{allow_blank}})
          if ({{in}}).includes?(value)
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

      # TODO: add scope

      macro validates_uniqueness(field, allow_blank = false)
        validates_with_method(%validate_method)

        def %validate_method
          value = _not_nil_validation({{field}}, {{allow_blank}})
          query = self.class.where { _{{field.id}} == value }
          unless new_record?
            this = self
            query = query.where { primary != this.primary }
          end

          errors.add({{field}}, self.class.human_error({{field}}, :taken)) if query.exists?
        end
      end

      macro validates_presence(field)
        validates_with_method(%validate_method)

        def %validate_method
          value = @{{field.id}}
          if value.blank?
            errors.add({{field}}, self.class.human_error({{field}}, :blank))
          end
        end
      end

      macro validates_absence(field)
        validates_with_method(%validate_method)

        def %validate_method
          value = @{{field.id}}
          if value.present?
            errors.add({{field}}, self.class.human_error({{field}}, :present))
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

      macro validates_acceptance(field, accept = nil)
        validates_with_method(%validate_method)

        def %validate_method
          value = @{{field.id}}
          {% condition = accept ? "!(#{accept}).includes?(value)" : "value != true && value != '1'" %}
          if {{condition.id}}
            errors.add({{field}}, self.class.human_error({{field}}, :accepted))
          end
        end
      end

      macro validates_confirmation(field, case_sensitive = true)
        validates_with_method(%validate_method)

        def %validate_method
          return if @{{field.id}}_confirmation.nil?
          value = _not_nil_validation({{field}}, false)

          if value.compare(@{{field.id}}_confirmation.not_nil!, !{{case_sensitive}}) != 0
            errors.add(
              {{field}},
              self.class.human_error(
                {{field}},
                :confirmation,
                options: { :attribute => self.class.human_attribute_name(:{{field.id}}) }
              )
            )
          end
        end
      end
    end
  end
end
