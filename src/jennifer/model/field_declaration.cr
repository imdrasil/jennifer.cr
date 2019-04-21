module Jennifer::Model
  module FieldDeclaration
    # :nodoc:
    macro __bool_convert(value, type)
      {% if type.stringify == "Bool" %}
        ({{value.id}}.is_a?(Int8) ? {{value.id}} == 1i8 : {{value.id}}.as({{type}}))
      {% else %}
        {{value}}.as({{type}})
      {% end %}
    end

    # TODO: remove .primary_field_type method as it isn't used anywhere

    # :nodoc:
    macro __field_declaration(properties, primary_auto_incrementable)
      {% for key, value in properties %}
        @{{key.id}} : {{value[:parsed_type].id}}
        @[JSON::Field(ignore: true)]
        @{{key.id}}_changed = false

        {% if value[:setter] != false %}
          def {{key.id}}=(_{{key.id}} : {{value[:parsed_type].id}})
            {% if !value[:virtual] %}
              @{{key.id}}_changed = true if _{{key.id}} != @{{key.id}}
            {% end %}
            @{{key.id}} = _{{key.id}}
          end

          def {{key.id}}=(_{{key.id}} : ::Jennifer::DBAny)
            {% if !value[:virtual] %}
              @{{key.id}}_changed = true if _{{key.id}} != @{{key.id}}
            {% end %}
            @{{key.id}} = _{{key.id}}.as({{value[:parsed_type].id}})
          end
        {% end %}

        {% if value[:getter] != false %}
          def {{key.id}}
            @{{key.id}}
          end

          {% if value[:null] != false %}
            def {{key.id}}!
              @{{key.id}}.not_nil!
            end
          {% end %}

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

          def self._{{key}}
            c({{value[:column]}})
          end

          {% if value[:primary] %}
            # :nodoc:
            def primary
              @{{key.id}}
            end

            # :nodoc:
            def self.primary
              c({{value[:column]}})
            end

            # :nodoc:
            def self.primary_field_name
              "{{key.id}}"
            end

            # :nodoc:
            def self.primary_field_type
              {{value[:parsed_type].id}}
            end

            # :nodoc:
            def init_primary_field(value : Int)
              {% if primary_auto_incrementable %}
                raise ::Jennifer::AlreadyInitialized.new(@{{key.id}}, value) if @{{key.id}}
                @{{key.id}} = value{% if value[:parsed_type] =~ /32/ %}.to_i{% else %}.to_i64{% end %}
              {% end %}
            end

            # :nodoc:
            def init_primary_field(value); end
          {% end %}
        {% end %}
      {% end %}
    end
  end
end
