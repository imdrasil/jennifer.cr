module Jennifer
  module View
    module ExperimentalMapping
      # Generates getter and setters
      macro __field_declaration
        {% for key, value in FIELDS %}
          @{{key.id}} : {{value["parsed_type"].id}}

          {% if value["setter"] == nil || value["setter"] == "true" %}
            def {{key.id}}=(_{{key.id}} : {{value["parsed_type"].id}})
              @{{key.id}} = _{{key.id}}
            end
          {% end %}

          {% if value["getter"] == nil || value["getter"] == "true" %}
            def {{key.id}}
              @{{key.id}}
            end

            {% if value["null"] == nil || value["null"] == "true" %}
              def {{key.id}}!
                @{{key.id}}.not_nil!
              end
            {% end %}
          {% end %}

          def self._{{key.id}}
            c({{key}})
          end

          {% if value["primary"] == "true" %}
            def primary
              @{{key.id}}
            end

            def self.primary
              c({{key}})
            end

            def self.primary_field_name
              {{key}}
            end

            def self.primary_field_type
              {{value["type"].id}}
            end
          {% end %}
        {% end %}
      end

      macro __instance_methods
        {% strict = true %}

        # Creates object from `DB::ResultSet`
        def initialize(%pull : DB::ResultSet)
          {% left_side = [] of String %}
          {% for key in FIELDS.keys %}
            {% left_side << "@#{key.id}" %}
          {% end %}
          {{left_side.join(", ").id}} = _extract_attributes(%pull)
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny))
          {% left_side = [] of String %}
          {% for key in FIELDS.keys %}
            {% left_side << "@#{key.id}" %}
          {% end %}
          {{left_side.join(", ").id}} = _extract_attributes(values)
        end

        # Accepts symbol hash or named tuple, stringify it and calls
        # TODO: check how converting affects performance
        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          initialize(stringify_hash(values, Jennifer::DBAny))
        end

        def initialize(values : Hash | NamedTuple, new_record)
          initialize(values)
        end

        # Extracts arguments due to mapping from *pull* and returns tuple for
        # fields assignment. It stands on that fact result set has all defined fields in a raw
        # TODO: think about moving it to class scope
        # NOTE: don't use it manually - there is some dependencies on caller such as reading tesult set to the end
        #  if eception was raised
        def _extract_attributes(pull : DB::ResultSet)
          {% for key in FIELDS.keys %}
            %var{key.id} = nil
            %found{key.id} = false
          {% end %}
          own_attributes = {{ FIELDS.size }}
          pull.each_column do |column|
            break if own_attributes == 0
            case column
            {% for key, value in FIELDS %}
              when {{value["column_name"] ? value["column_name"].id : key.id.stringify}}
                own_attributes -= 1
                %found{key.id} = true
                begin
                  %var{key.id} = pull.read({{value["parsed_type"].id}})
                rescue e : Exception
                  raise ::Jennifer::DataTypeMismatch.new(column, {{@type}}, e) if ::Jennifer::DataTypeMismatch.match?(e)
                  raise e
                end
            {% end %}
            else
              {% if STRICT_MAPPNIG %}
                raise ::Jennifer::BaseException.new("Undefined column #{column} for model {{@type}}.")
              {% else %}
                pull.read
              {% end %}
            end
          end
          pull.read_to_end
          {% if STRICT_MAPPNIG %}
            {% for key in FIELDS.keys %}
              unless %found{key.id}
                raise ::Jennifer::BaseException.new("Column #{{{@type}}}##{{{key.id.stringify}}} hasn't been found in the result set.")
              end
            {% end %}
          {% end %}
          {% if FIELDS.size > 1 %}
            {
            {% for key, value in FIELDS %}
              begin
                %var{key.id}.as({{value["parsed_type"].id}})
              rescue e : Exception
                raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
                raise e
              end,
            {% end %}
            }
          {% else %}
            {% key = FIELDS.keys[0] %}
            begin
              %var{key}.as({{FIELDS[key]["parsed_type"].id}})
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
              raise e
            end
          {% end %}
        end

        # Extracts attributes from gien hash to the tuple. If hash has no some field - will not raise any error.
        def _extract_attributes(values : Hash(String, ::Jennifer::DBAny))
          {% for key in FIELDS.keys %}
            %var{key.id} = nil
            %found{key.id} = true
          {% end %}

          {% for key, value in FIELDS %}
            {% _key = value["column_name"] ? value["column_name"] : key.id.stringify %}
            if !values[{{_key}}]?.nil?
              %var{key.id} = values[{{_key}}]
            else
              %found{key.id} = false
            end
          {% end %}

          {% for key, value in FIELDS %}
            begin
              {% if value["null"] == "true" %}
                {% if value["default"] != nil %}
                  %casted_var{key.id} = %found{key.id} ? Jennifer::Model::Mapping.__bool_convert(%var{key.id}, {{value["parsed_type"].id}}) : {{value["default"].id}}
                {% else %}
                  %casted_var{key.id} = %var{key.id}.as({{value["parsed_type"].id}})
                {% end %}
              {% elsif value["default"] != nil %}
                %casted_var{key.id} = %var{key.id}.is_a?(Nil) ? {{value["default"]}} : Jennifer::Model::Mapping.__bool_convert(%var{key.id}, {{value["parsed_type"].id}})
              {% else %}
                %casted_var{key.id} = Jennifer::Model::Mapping.__bool_convert(%var{key.id}, {{value["parsed_type"].id}})
              {% end %}
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
              raise e
            end
          {% end %}

          {% if FIELDS.size > 1 %}
            {
            {% for key, value in FIELDS %}
              %casted_var{key.id},
            {% end %}
            }
          {% else %}
            {% key = FIELDS.keys[0] %}
            %casted_var{key}
          {% end %}
        end

        # Reloads all fields from db
        def reload
          this = self
          self.class.all.where { this.class.primary == this.primary }.each_result_set do |rs|
            {{FIELDS.keys.map { |f| "@#{f.id}" }.join(", ").id}} = _extract_attributes(rs)
          end
          self
        end

        # Returns hash with all attributes and symbol keys
        def to_h
          {
            {% for key in FIELDS.keys %}
              :{{key.id}} => @{{key.id}},
            {% end %}
          }
        end

        # Returns hash with all attributes and string keys
        def to_str_h
          {
            {% for key in FIELDS.keys %}
              {{key}} => @{{key.id}},
            {% end %}
          }
        end

        # Returns field by given name. If object has no such field - will raise `BaseException`.
        # To avoid raising exception set `raise_exception` to `false`.
        def attribute(name : String | Symbol, raise_exception = true)
          case name.to_s
          {% for key, value in FIELDS.keys %}
          when {{key}}
            @{{key.id}}
          {% end %}
          else
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}") if raise_exception
          end
        end

        def attributes_hash
          hash = to_h
          {% for key, value in FIELDS %}
            {% if !value["null"] || value["primary"] %}
              hash.delete(:{{key.id}}) if hash[:{{key.id}}]?.nil?
            {% end %}
          {% end %}
          hash
        end
      end

      macro included
        macro inherited
          FIELDS = {} of String => Hash(String, String)

          macro finished
            __field_declaration
            __instance_methods
          end
        end
      end

      macro mapping(properties, strict = true)
        macro def self.children_classes
          {% begin %}
            {% if @type.all_subclasses.size > 0 %}
              [{{ @type.all_subclasses.join(", ").id }}]
            {% else %}
              [] of ::Jennifer::View::Base.class
            {% end %}
          {% end %}
        end

        FIELD_NAMES = [
          {% for key, v in properties %}
            "{{key.id}}",
          {% end %}
        ]

        STRICT_MAPPNIG = {{strict}}

        @@strict_mapping : Bool?

        def self.strict_mapping?
          @@strict_mapping ||= ::Jennifer::Adapter.adapter.table_column_count(table_name) == field_count
        end

        # Returns field count
        def self.field_count
          {{properties.size}}
        end

        # Returns array of field names
        def self.field_names
          FIELDS.keys
        end

        {% primary_auto_incrementable = false %}
        {% primary = nil %}

        # generates hash with options
        {% for key, opt in properties %}
          {% _key = key.id.stringify %}
          {% unless opt.is_a?(HashLiteral) || opt.is_a?(NamedTupleLiteral) %}
            {% FIELDS[_key] = {"type" => opt.stringify} %}
            {% properties[key] = {type: opt} %}
          {% else %}
            {% FIELDS[_key] = {} of String => String %}
            {% for attr, value in opt %}
              {% FIELDS[_key][attr.id.stringify] = properties[key][attr].stringify %}
            {% end %}
          {% end %}
          {% if properties[key][:primary] %}
            {% primary = key %}
          {% end %}
          {% t_string = properties[key][:type].stringify %}
          {% properties[key][:parsed_type] = properties[key][:null] || properties[key][:primary] ? t_string + "?" : t_string %}
          {% FIELDS[_key]["parsed_type"] = properties[key][:parsed_type] %}
        {% end %}

        # TODO: find way to allow model definition without any primary field
        {% if primary == nil %}
          {% raise "Model #{@type} has no defined primary field. For now model without primary field is not allowed" %}
        {% end %}

        # Returns if primary field is autoincrementable
        def self.primary_auto_incrementable?
          {{primary_auto_incrementable}}
        end
      end

      macro mapping(**properties)
        mapping({{properties}})
      end
    end
  end
end
