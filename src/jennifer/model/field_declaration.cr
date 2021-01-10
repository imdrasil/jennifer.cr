module Jennifer::Model
  # :nodoc:
  module FieldDeclaration
    # :nodoc:
    macro __field_declaration(properties, primary_auto_incrementable)
      {% for key, value in properties %}
        @{{key.id}} : {{value[:parsed_type].id}}
        @[JSON::Field(ignore: true)]
        @{{key.id}}_changed = false

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

          {% unless value[:parsed_type] =~ /String/ %}
            def {{key.id}}=(_{{key.id}} : String)
              return self.{{key.id}} = nil{% if !value[:null] %}.not_nil! {% end %} if _{{key.id}}.empty?

              {%
                method =
                  if value[:parsed_type] =~ /Array/
                    "not_supported"
                  elsif value[:parsed_type] =~ /Int16/
                    "to_i16"
                  elsif value[:parsed_type] =~ /Int64/
                    "to_i64"
                  elsif value[:parsed_type] =~ /Int/
                    "to_i"
                  elsif value[:parsed_type] =~ /Float32/
                    "to_f32"
                  elsif value[:parsed_type] =~ /Float/
                    "to_f"
                  elsif value[:parsed_type] =~ /Bool/
                    "to_bool"
                  elsif value[:parsed_type] =~ /JSON/
                    "to_json"
                  elsif value[:parsed_type] =~ /Time/
                    "to_time"
                  else
                    "not_supported"
                  end
              %}
              {% if method == "not_supported" %}
                raise ::Jennifer::BaseException.new("Type {{value[:parsed_type].id}} can't be coerced")
              {% else %}
                self.{{key.id}} = self.class.coercer.{{method.id}}(_{{key.id}})
              {% end %}
            end
          {% end %}
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
