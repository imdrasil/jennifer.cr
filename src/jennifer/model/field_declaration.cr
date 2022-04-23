module Jennifer::Model
  # :nodoc:
  module FieldDeclaration
    # :nodoc:
    macro __field_declaration(properties, primary_auto_incrementable)
      {% for key, value in properties %}
        @{{key.id}} : {{value[:parsed_type].id}}
        @[JSON::Field(ignore: true)]
        @{{key.id}}_changed = false

        # :nodoc:
        def self.coerce_{{key.id}}(_{{key.id}} : String)
          {% if value[:converter] && value[:converter].resolve.class.has_method?(:coerce) %}
            {{value[:converter]}}.coerce(_{{key.id}}, columns_tuple[:{{key.id}}])
          {% else %}
            coercer.coerce(_{{key.id}}, {{value[:parsed_type].id}})
          {% end %}
            {% if !value[:null] %}.not_nil!{% end %}
        end

        {% if value[:setter] != false %}
          def {{key.id}}=(_{{key.id}} : {{value[:parsed_type].id}})
            {% if !value[:virtual] %}
              {{key.id}}_will_change! if _{{key.id}} != @{{key.id}}
            {% end %}
            @{{key.id}} = _{{key.id}}
          end

          def {{key.id}}=(_{{key.id}} : AttrType)
            self.{{key.id}} = _{{key.id}}.as({{value[:parsed_type].id}})
          end

          {% if !value[:parsed_type].includes?("String") %}
            def {{key.id}}=(_{{key.id}} : String)
              self.{{key.id}} = self.class.coerce_{{key.id}}(_{{key.id}})
            end

            {% if value[:parsed_type].includes?("Int64") %}
              def {{key.id}}=(_{{key.id}} : Int32)
                self.{{key.id}} = _{{key.id}}.to_i64
              end
            {% end %}
          {% end %}
        {% end %}

        {% if value[:getter] != false %}
          def {{key.id}}
            @{{key.id}}
          end

          def {{key.id}}!
            @{{key.id}}.not_nil!
          end

          {% resolved_type = value[:type].resolve %}
          {% if resolved_type == Bool || (resolved_type.union? && resolved_type.union_types[0] == Bool) %}
            def {{key.id}}?
              {{key.id}} == true
            end
          {% end %}
        {% end %}

        {% if !value[:virtual] %}
          def {{key.id}}_changed?
            @{{key.id}}_changed
          end

          def {{key.id}}_will_change!
            @{{key.id}}_changed = true
          end

          def self._{{key}}
            c({{value[:column]}})
          end

          {% if value[:primary] %}
            # :nodoc:
            def primary
              {{key.id}}
            end

            # :nodoc:
            def self.primary
              c({{value[:column]}})
            end

            # :nodoc:
            def self.primary_field_name
              "{{key.id}}"
            end

            {% if primary_auto_incrementable %}
              # :nodoc:
              def init_primary_field(value : Int)
                raise ::Jennifer::AlreadyInitialized.new(@{{key.id}}, value) if @{{key.id}}
                @{{key.id}} = value{% if value[:parsed_type] =~ /32/ %}.to_i{% else %}.to_i64{% end %}
              end
            {% end %}

            # :nodoc:
            def init_primary_field(value); end
          {% end %}
        {% end %}
      {% end %}
    end
  end
end
