module Jennifer
  module Model
    module Mapping
      macro __bool_convert(value, type)
        {% if type.stringify == "Bool" %}
          ({{value.id}}.is_a?(Int8) ? {{value.id}} == 1i8 : {{value.id}}.as({{type}}))
        {% else %}
          {{value}}.as({{type}})
        {% end %}
      end

      macro __field_declaration(properties, primary_auto_incrementable)
        # generates getter and setters
        {% for key, value in properties %}
          @{{key.id}} : {{value[:parsed_type].id}}
          @{{key.id}}_changed = false

          {% if value[:setter] == nil ? true : value[:setter] %}
            def {{key.id}}=(_{{key.id}} : {{value[:parsed_type].id}})
              @{{key.id}}_changed = true if _{{key.id}} != @{{key.id}}
              @{{key.id}} = _{{key.id}}
            end
          {% end %}

          {% if value[:getter] == nil ? true : value[:getter] %}
            def {{key.id}}
              @{{key.id}}
            end

            {% if value[:null] == nil ? true : value[:null] %}
              def {{key.id}}!
                @{{key.id}}.not_nil!
              end
            {% end %}
          {% end %}

          def {{key.id}}_changed?
            @{{key.id}}_changed
          end

          def self._{{key}}
            c("{{key.id}}")
          end

          {% if value[:primary] %}
            def primary
              @{{key.id}}
            end

            def self.primary
              c("{{key.id}}")
            end

            def self.primary_field_name
              "{{key.id}}"
            end

            def self.primary_field_type
              {{value[:type]}}
            end

            {% if primary_auto_incrementable %}
              # Inits primary field
              def init_primary_field(value : {{value[:type]}})
                raise "Primary field is already initialized" if @{{key.id}}
                @{{key.id}} = value
              end
            {% end %}
          {% end %}
        {% end %}
      end

      # Adds callbacks for `created_at` and `updated_at` fields
      macro with_timestamps
        before_create :__update_created_at
        before_save :__update_updated_at

        # Sets `created_at` tocurrent time
        def __update_created_at
          @created_at = Time.now
        end

        # Sets `updated_at` to current time
        def __update_updated_at
          @updated_at = Time.now
        end
      end

      macro mapping(properties, strict = true)
        macro def self.children_classes
          {% begin %}
            {% if @type.all_subclasses.size > 0 %}
              [{{ @type.all_subclasses.join(", ").id }}]
            {% else %}
              [] of Model::Base.class
            {% end %}
          {% end %}
        end

        FIELD_NAMES = [
          {% for key, v in properties %}
            "{{key.id}}",
          {% end %}
        ]

        # Returns field count
        def self.field_count
          {{properties.size}}
        end

        # Returns array of field names
        def self.field_names
          FIELD_NAMES
        end

        {% add_default_constructor = true %}

        # generates hash with options
        {% for key, value in properties %}
          {% unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
            {% properties[key] = {type: value} %}
          {% else %}
            {% properties[key][:type] = properties[key][:type] %}
          {% end %}
          {% if properties[key][:primary] %}
            {% primary = key %}
            {% primary_type = properties[key][:type] %}
            {% primary_auto_incrementable = ["Int32", "Int64"].includes?(properties[key][:type].stringify) %}
          {% end %}
          {% t_string = properties[key][:type].stringify %}
          {% properties[key][:parsed_type] = properties[key][:null] || properties[key][:primary] ? t_string + "?" : t_string %}
          {% add_default_constructor = add_default_constructor && (properties[key][:primary] || properties[key][:null] || properties[key].keys.includes?(:default)) %}
        {% end %}

        __field_declaration({{properties}}, {{primary_auto_incrementable}})

        # Returns if primary field is autoincrementable
        def self.primary_auto_incrementable?
          {{primary_auto_incrementable}}
        end

        @new_record = true
        @destroyed = false

        # Creates object from `DB::ResultSet`
        def initialize(%pull : DB::ResultSet)
          @new_record = false
          {% left_side = [] of String %}
          {% for key in properties.keys %}
            {% left_side << "@#{key.id}" %}
          {% end %}
          {{left_side.join(", ").id}} = _extract_attributes(%pull)
        end

        # Extracts arguments due to mapping from *pull* and returns tuple for
        # fields assignment
        # TODO: think about moving it to class scope
        def _extract_attributes(pull : DB::ResultSet)
          {% for key, value in properties %}
            %var{key.id} = nil
            %found{key.id} = false
          {% end %}

          pull.column_count.times do |i|
            column = pull.column_name(pull.column_index)
            case column
            {% for key, value in properties %}
              when {{value[:column_name] || key.id.stringify}}
                %found{key.id} = true
                %var{key.id} = pull.read({{value[:parsed_type].id}})
                # if value[:type].is_a?(Path) || value[:type].is_a?(Generic)
            {% end %}
            else
              {% if strict %}
                raise ::Jennifer::BaseException.new("Undefined column #{column}")
              {% else %}
                pull.read
              {% end %}
            end
          end
          {% if properties.size > 1 %}
            {
            {% for key, value in properties %}
              %var{key.id}.as({{value[:parsed_type].id}}),
            {% end %}
            }
          {% else %}
            {% key = properties.keys[0] %}
            %var{key}.as({{properties[key][:parsed_type].id}})
          {% end %}
        end

        # Accepts symbol hash or named tuple, stringify it and calls
        # TODO: check how converting affects performance
        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          initialize(stringify_hash(values, Jennifer::DBAny))
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny))
          {% for key, value in properties %}
            %var{key.id} = nil
            %found{key.id} = true
          {% end %}

          {% for key, value in properties %}
            if !values["{{key.id}}"]?.nil?
              %var{key.id} = values["{{key.id}}"]
            else
              %found{key.id} = false
            end
          {% end %}


          {% for key, value in properties %}
            {% if value[:null] %}
              {% if value[:default] != nil %}
                @{{key.id}} = %found{key.id} ? __bool_convert(%var{key.id}, {{value[:parsed_type].id}}) : {{value[:default]}}
              {% else %}
                @{{key.id}} = %var{key.id}.as({{value[:parsed_type].id}})
              {% end %}
            {% elsif value[:default] != nil %}
              @{{key.id}} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : __bool_convert(%var{key.id}, {{value[:parsed_type].id}})
            {% else %}
              @{{key.id}} = __bool_convert(%var{key.id}, {{value[:parsed_type].id}})
            {% end %}
          {% end %}
        end

        def initialize(values : Hash | NamedTuple, @new_record)
          initialize(values)
        end

        #def attributes=(values : Hash)
        # {% for key, value in properties %}
        #    if !values[:{{key.id}}]?.nil?
        #      %var{key.id} = values[:{{key.id}}]
        #    elsif !values["{{key.id}}"]?.nil?
        #      %var{key.id} = values["{{key.id}}"]
        #    else
        #      %found{key.id} = false
        #    end
        #  {% end %}
        #end

        {% if add_default_constructor %}
          # Default constructor without any fields
          def initialize
            {% for key, value in properties %}
              @{{key.id}} =
                {% if value[:null] %}
                  {% if value[:default] != nil %}
                    {{value[:default]}}
                  {% else %}
                    nil
                  {% end %}
                {% elsif value[:default] != nil %}
                  {{value[:default]}}
                {% else %}
                  nil
                {% end %}
            {% end %}
          end
        {% end %}

        # Saves all changes to db; if validation not passed - returns `false`
        def save(skip_validation = false)
          unless skip_validation
            return false unless __before_validation_callback
            validate!
            __after_validation_callback
            return false unless valid?
          end
          return false unless __before_save_callback
          response =
            if new_record?
              return false unless __before_create_callback
              res = ::Jennifer::Adapter.adapter.insert(self)
              {% if primary && primary_auto_incrementable %}
                if primary.nil? && res.last_insert_id > -1
                  init_primary_field(res.last_insert_id.to_i)
                end
              {% end %}
              @new_record = false if res.rows_affected != 0
              __after_create_callback
              res
            else
              ::Jennifer::Adapter.adapter.update(self)
            end
          __after_save_callback
          response.rows_affected == 1
        end

        # Reloads all fields from db
        def reload
          raise ::Jennifer::RecordNotFound.new("It is not persisted yet") if new_record?
          this = self
          self.class.where { this.class.primary == this.primary }.each_result_set do |rs|
            {% left_side = [] of String %}
            {% for key in properties.keys %}
              {% left_side << "@#{key.id}" %}
            {% end %}
            {{left_side.join(", ").id}} = _extract_attributes(rs)
          end
          self
        end

        # Returns if any field was changed. If field again got first value - `true` anyway
        # will be returned
        def changed?
          {% for key, value in properties %}
            @{{key.id}}_changed ||
          {% end %}
          false
        end

        # Returns hash with all attributes and symbol keys
        def to_h
          {
            {% for key, value in properties %}
              :{{key.id}} => @{{key.id}},
            {% end %}
          }
        end

        # Returns hash with all attributes and string keys
        def to_str_h
          {
            {% for key, value in properties %}
              {{key.stringify}} => @{{key.id}},
            {% end %}
          }
        end

        # Sets *value* to field with name *name* and stores them directly to db without
        # any validation or callback
        def update_column(name, value : Jennifer::DBAny)
          update_columns({name => value})
        end

        # Sets given *values* to proper fields and stores them directly to db without
        # any validation or callback
        def update_columns(values : Hash(String | Symbol, Jennifer::DBAny))
          values.each do |name, value|
            case name.to_s
            {% for key, value in properties %}
            when "{{key.id}}"
              if value.is_a?({{value[:parsed_type].id}})
                local = value.as({{value[:parsed_type].id}})
                @{{key.id}} = local
              else
                raise ::Jennifer::BaseException.new("Wrong type for #{name} : #{value.class}")
              end
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}")
            end
          end

          _primary = self.class.primary
          _primary_value = primary
          ::Jennifer::Adapter.adapter.update(self.class.all.where { _primary == _primary_value }, values)
        end

        # Sets *name* field with *value*
        def set_attribute(name, value : Jennifer::DBAny)
          case name.to_s
          {% for key, value in properties %}
            {% if value[:setter] == nil ? true : value[:setter] %}
              when "{{key.id}}"
                if value.is_a?({{value[:parsed_type].id}})
                  self.{{key.id}} = value.as({{value[:parsed_type].id}})
                else
                  raise ::Jennifer::BaseException.new("wrong type for #{name} : #{value.class}")
                end
            {% end %}
          {% end %}
          else
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}")
          end
        end

        # Returns field by given name. If object has no such field - will raise `BaseException`.
        # To avoid raising exception set `raise_exception` to `false`.
        def attribute(name : String | Symbol, raise_exception = true)
          case name.to_s
          {% for key, value in properties %}
          when "{{key.id}}"
            @{{key.id}}
          {% end %}
          else
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}") if raise_exception
          end
        end

        def attributes_hash
          hash = to_h
          {% for key, value in properties %}
            {% if !value[:null] || value[:primary] %}
              hash.delete(:{{key}}) if hash[:{{key}}]?.nil?
            {% end %}
          {% end %}
          hash
        end

        def arguments_to_save
          args = [] of ::Jennifer::DBAny
          fields = [] of String
          {% for key, value in properties %}
            {% unless value[:primary] %}
              if @{{key.id}}_changed
                args << {% if value[:type].stringify == "JSON::Any" %}
                          @{{key.id}}.to_json
                        {% else %}
                          @{{key.id}}
                        {% end %}
                fields << "{{key.id}}"
              end
            {% end %}
          {% end %}
          {args: args, fields: fields}
        end

        def arguments_to_insert
          args = [] of ::Jennifer::DBAny
          fields = [] of String
          {% for key, value in properties %}
            {% unless value[:primary] && primary_auto_incrementable %}
              args << {% if value[:type].stringify == "JSON::Any" %}
                        (@{{key.id}} ? @{{key.id}}.to_json : nil)
                      {% else %}
                        @{{key.id}}
                      {% end %}
              fields << "{{key.id}}"
            {% end %}
          {% end %}
          {args: args, fields: fields}
        end

        private def __refresh_changes
          {% for key, value in properties %}
            @{{key.id}}_changed = false
          {% end %}
        end
      end

      macro mapping(**properties)
        mapping({{properties}})
      end
    end
  end
end
