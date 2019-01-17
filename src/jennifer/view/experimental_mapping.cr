module Jennifer
  module View
    module ExperimentalMapping
      # :nodoc:
      macro __field_declaration
        {% for key, value in COLUMNS_METADATA %}
          @{{key.id}} : {{value[:parsed_type].id}}

          {% if value[:setter] != false %}
            def {{key.id}}=(_{{key.id}} : {{value[:parsed_type].id}})
              @{{key.id}} = _{{key.id}}
            end
          {% end %}

          {% if value[:getter] != false %}
            def {{key.id}}
              @{{key.id}}
            end

            {% resolved_type = value[:type].resolve %}
            {% if resolved_type == Bool || (resolved_type.union? && resolved_type.union_types[0] == Bool) %}
              def {{key.id}}?
                {{key.id}} == true
              end
            {% end %}

            {% if value[:null] != false %}
              def {{key.id}}!
                @{{key.id}}.not_nil!
              end
            {% end %}
          {% end %}

          def self._{{key}}
            c({{key.stringify}})
          end

          {% if value[:primary] %}
            # :nodoc:
            def primary
              @{{key.id}}
            end

            # :nodoc:
            def self.primary
              c({{key.stringify}})
            end

            # :nodoc:
            def self.primary_field_name
              {{key.stringify}}
            end

            # :nodoc:
            def self.primary_field_type
              {{value[:parsed_type].id}}
            end
          {% end %}
        {% end %}
      end

      # :nodoc:
      macro __instance_methods
        private def inspect_attributes(io) : Nil
          io << ' '
          {% for var, i in COLUMNS_METADATA.keys %}
            {% if i > 0 %}
              io << ", "
            {% end %}
            io << "{{var.id}}: "
            @{{var.id}}.inspect(io)
          {% end %}
          nil
        end

        # Creates object from `DB::ResultSet`
        def initialize(%pull : DB::ResultSet)
          {{COLUMNS_METADATA.keys.map { |f| "@#{f.id}" }.join(", ").id}} = _extract_attributes(%pull)
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny))
          {{COLUMNS_METADATA.keys.map { |f| "@#{f.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        # Accepts symbol hash or named tuple, stringify it and calls
        # TODO: check how converting affects performance
        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          initialize(Ifrit.stringify_hash(values, Jennifer::DBAny))
        end

        def initialize(values : Hash | NamedTuple, new_record)
          initialize(values)
        end

        # Extracts arguments due to mapping from *pull* and returns tuple for fields assignment.
        # It stands on that fact result set has all defined fields in a raw
        # TODO: think about moving it to class scope
        # NOTE: don't use it manually - there is some dependencies on caller such as reading result set to the end
        # if exception was raised
        private def _extract_attributes(pull : DB::ResultSet)
          {% for key in COLUMNS_METADATA.keys %}
            %var{key.id} = nil
            %found{key.id} = false
          {% end %}
          own_attributes = {{COLUMNS_METADATA.size}}
          pull.each_column do |column|
            break if own_attributes == 0
            case column
            {% for key, value in COLUMNS_METADATA %}
              when {{(value[:column_name] || key).id.stringify}}
                own_attributes -= 1
                %found{key.id} = true
                begin
                  %var{key.id} = pull.read({{value[:parsed_type].id}})
                rescue e : Exception
                  raise ::Jennifer::DataTypeMismatch.build(column, {{@type}}, e)
                end
            {% end %}
            else
              {% if STRICT_MAPPING %}
                raise ::Jennifer::BaseException.new("Undefined column #{column} for model {{@type}}.")
              {% else %}
                pull.read
              {% end %}
            end
          end
          pull.read_to_end
          {% if STRICT_MAPPING %}
            {% for key in COLUMNS_METADATA.keys %}
              unless %found{key.id}
                raise ::Jennifer::BaseException.new("Column #{{{@type}}}.{{key.id}} hasn't been found in the result set.")
              end
            {% end %}
          {% end %}
          {% if COLUMNS_METADATA.size > 1 %}
            {
            {% for key, value in COLUMNS_METADATA %}
              begin
                res = %var{key.id}.as({{value[:parsed_type].id}})
                !res.is_a?(Time) ? res : res.in(::Jennifer::Config.local_time_zone)
              rescue e : Exception
                raise ::Jennifer::DataTypeCasting.build({{key.id.stringify}}, {{@type}}, e)
              end,
            {% end %}
            }
          {% else %}
            {% key = COLUMNS_METADATA.keys[0] %}
            begin
              %var{key}.as({{COLUMNS_METADATA[key][:parsed_type].id}})
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.build({{key.id.stringify}}, {{@type}}, e)
            end
          {% end %}
        end

        # Extracts attributes from given hash to the tuple. If hash has no some field - will not raise any error.
        private def _extract_attributes(values : Hash(String, ::Jennifer::DBAny))
          {% for key in COLUMNS_METADATA.keys %}
            %var{key.id} = nil
            %found{key.id} = true
          {% end %}

          {% for key, value in COLUMNS_METADATA %}
            {% _key = (value[:column_name] || key).id.stringify %}
            if values.has_key?({{_key}})
              %var{key.id} = values[{{_key}}]
            else
              %found{key.id} = false
            end
          {% end %}

          {% for key, value in COLUMNS_METADATA %}
            begin
              {% if value[:null] %}
                {% if value[:default] != nil %}
                  %casted_var{key.id} = %found{key.id} ? Jennifer::Model::Mapping.__bool_convert(%var{key.id}, {{value["parsed_type"].id}}) : {{value["default"].id}}
                {% else %}
                  %casted_var{key.id} = %var{key.id}.as({{value[:parsed_type].id}})
                {% end %}
              {% elsif value["default"] != nil %}
                %casted_var{key.id} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : Jennifer::Model::Mapping.__bool_convert(%var{key.id}, {{value["parsed_type"].id}})
              {% else %}
                %casted_var{key.id} = Jennifer::Model::Mapping.__bool_convert(%var{key.id}, {{value["parsed_type"].id}})
              {% end %}
              %casted_var{key.id} = !%casted_var{key.id}.is_a?(Time) ? %casted_var{key.id} : %casted_var{key.id}.in(::Jennifer::Config.local_time_zone)
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.build({{key.id.stringify}}, {{@type}}, e)
            end
          {% end %}

          {% if COLUMNS_METADATA.size > 1 %}
            {
            {% for key, value in COLUMNS_METADATA %}
              %casted_var{key.id},
            {% end %}
            }
          {% else %}
            {% key = COLUMNS_METADATA.keys[0] %}
            %casted_var{key}
          {% end %}
        end

        # :nodoc:
        def reload
          this = self
          self.class.all.where { this.class.primary == this.primary }.each_result_set do |rs|
            {{COLUMNS_METADATA.keys.map { |f| "@#{f.id}" }.join(", ").id}} = _extract_attributes(rs)
          end
          self
        end

        # :nodoc:
        def to_h
          {
            {% for key in COLUMNS_METADATA.keys %}
              :{{key.id}} => {{key.id}},
            {% end %}
          }
        end

        # :nodoc:
        def to_str_h
          {
            {% for key in COLUMNS_METADATA.keys %}
              {{key.stringify}} => {{key.id}},
            {% end %}
          }
        end

        # :nodoc:
        def attribute(name : String | Symbol, raise_exception = true)
          case name.to_s
          {% for key in COLUMNS_METADATA.keys %}
          when {{key.stringify}}
            @{{key.id}}
          {% end %}
          else
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}") if raise_exception
          end
        end
      end

      macro included
        macro inherited
          # :nodoc:
          FIELDS = {} of String => Hash(String, String)

          macro finished
            \\{% if @type.constant("COLUMNS_METADATA") %}
              __field_declaration
              __instance_methods
            \\{% end %}
          end
        end
      end

      macro mapping(properties, strict = true)
        # :nodoc:
        STRICT_MAPPING = {{strict}}

        # :nodoc:
        def self.field_count
          {{properties.size}}
        end

        # :nodoc:
        def self.field_names
          COLUMNS_METADATA.keys.to_a.map(&.to_s)
        end

        {% primary = nil %}

        # generates hash with options
        {% for key, opt in properties %}
          {%
            _key = key.id.stringify
            str_properties = FIELDS[_key] = {} of String => String
            properties[key] = {type: opt} unless opt.is_a?(HashLiteral) || opt.is_a?(NamedTupleLiteral)
            options = properties[key]
          %}

          {% for attr, value in options %}
            {% str_properties[attr.id.stringify] = value.stringify %}
          {% end %}

          {% if options[:type].is_a?(Path) && Jennifer::Macros::TYPES.includes?(str_properties["type"]) %}
            {% for tkey, tvalue in options[:type].resolve %}
              {% if tkey == :type || options[tkey] == nil %}
                {%
                  options[tkey] = tvalue
                  str_properties[tkey.stringify] = tvalue.stringify
                %}
              {% end %}
            {% end %}
          {% end %}

          {%
            stringified_type = str_properties["type"]
            primary = key if options[:primary]
            if stringified_type =~ Jennifer::Macros::NILLABLE_REGEXP
              options[:null] = true
              str_properties["null"] = "true"
              str_properties["parsed_type"] = options[:parsed_type] = stringified_type
            else
              options[:parsed_type] = options[:null] || options[:primary] ? stringified_type + "?" : stringified_type
              str_properties["parsed_type"] = options[:parsed_type]
            end
          %}
        {% end %}

        # TODO: find way to allow view definition without any primary field
        {% raise "Model #{@type} has no defined primary field. For now model without primary field is not allowed" if primary == nil %}

        # :nodoc:
        COLUMNS_METADATA = {{properties}}

        # :nodoc:
        def self.columns_tuple
          COLUMNS_METADATA
        end
      end

      macro mapping(**properties)
        mapping({{properties}})
      end
    end
  end
end
