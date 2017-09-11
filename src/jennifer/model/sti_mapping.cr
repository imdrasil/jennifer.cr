module Jennifer
  module Model
    module STIMapping
      macro sti_mapping(properties)
        def self.sti_condition
          c("type") == {{@type.id.stringify}}
        end

        def self.table_name
          superclass.table_name
        end

        def self.singular_table_name
          superclass.table_name
        end

        def self.table_name(name)
          raise "You can't specify table name using STI on subclasses"
        end

        def self.singular_table_name(name)
          raise "You can't specify table name using STI on subclasses"
        end

        FIELD_NAMES = [
          {% for key, v in properties %}
            "{{key.id}}",
          {% end %}
        ]

        def self.field_count
          super + {{properties.size}}
        end

        def self.field_names
          super + FIELD_NAMES
        end

        # generating hash with options
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
        {% end %}

        __field_declaration({{properties}}, false)

        @new_record = true

        def _sti_extract_attributes(values : Hash(String, ::Jennifer::DBAny))
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
            begin
              {% if value[:null] %}
                {% if value[:default] != nil %}
                  %var{key.id} = %found{key.id} ? __bool_convert(%var{key.id}, {{value[:parsed_type].id}}) : {{value[:default]}}
                {% else %}
                  %var{key.id} = %var{key.id}.as({{value[:parsed_type].id}})
                {% end %}
              {% elsif value[:default] != nil %}
                %var{key.id} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : __bool_convert(%var{key.id}, {{value[:parsed_type].id}})
              {% else %}
                %var{key.id} = __bool_convert(%var{key.id}, {{value[:parsed_type].id}})
              {% end %}
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
              raise e
            end
          {% end %}

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

        # creates object from db tuple
        def initialize(%pull : DB::ResultSet)
          initialize(::Jennifer::Adapter.adapter.result_to_hash(%pull), false)
        end

        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          initialize(stringify_hash(values, Jennifer::DBAny))
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny))
          # TODO: check why we are doing this
          values["type"] = "{{@type.id}}"
          super
          {% left_side = [] of String %}
          {% for key in properties.keys %}
            {% left_side << "@#{key.id}" %}
          {% end %}
          {{left_side.join(", ").id}} = _sti_extract_attributes(values)
        end

        def initialize(values : Hash | NamedTuple, @new_record)
          initialize(values)
        end

        def initialize
          initialize({} of String => ::Jennifer::DBAny)
        end

        def changed?
          super ||
          {% for key, value in properties %}
            @{{key.id}}_changed ||
          {% end %}
          false
        end

        def to_h
          hash = super
          {% for key, value in properties %}
            hash[:{{key.id}}] = @{{key.id}}
          {% end %}
          hash
        end

        def to_str_h
          hash = super
          {% for key, value in properties %}
            hash[{{key.stringify}}] = @{{key.id}}
          {% end %}
          hash
        end

        def update_column(name, value : Jennifer::DBAny)
          case name.to_s
          {% for key, value in properties %}
          when "{{key.id}}"
            if value.is_a?({{value[:parsed_type].id}})
              local = value.as({{value[:parsed_type].id}})
              @{{key.id}} = local
            else
              raise ::Jennifer::BaseException.new("rong type for #{name} : #{value.class}")
            end
          {% end %}
          end
          super
        end

        def update_columns(values : Hash(String | Symbol, Jennifer::DBAny))
          values.each do |name, value|
            case name.to_s
            {% for key, value in properties %}
            when "{{key.id}}"
              if value.is_a?({{value[:parsed_type].id}})
                local = value.as({{value[:parsed_type].id}})
                @{{key.id}} = local
              else
                raise ::Jennifer::BaseException.new("rong type for #{name} : #{value.class}")
              end
            {% end %}
            end
          end

          super
        end

        def set_attribute(name, value)
          case name.to_s
          {% for key, value in properties %}
            {% if value[:setter] == nil ? true : value[:setter] %}
              when "{{key.id}}"
                if value.is_a?({{value[:parsed_type].id}})
                  self.{{key.id}} = value.as({{value[:parsed_type].id}})
                else
                  raise ::Jennifer::BaseException.new("rong type for #{name} : #{value.class}")
                end
            {% end %}
          {% end %}
          else
            super
          end
        end

        def attribute(name : String, raise_exception = true)
          if raise_exception && !{{@type}}.field_names.includes?(name)
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}")
          end
          case name
          {% for key, value in properties %}
          when "{{key.id}}"
            @{{key.id}}
          {% end %}
          else
            super
          end
        end

        def attributes_hash
          hash = super
          {% for key, value in properties %}
            {% if !value[:null] || value[:primary] %}
              hash.delete(:{{key}}) if hash[:{{key}}]?.nil?
            {% end %}
          {% end %}
          hash
        end

        def arguments_to_save
          res = super
          args = res[:args]
          fields = res[:fields]
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
          res = super
          args = res[:args]
          fields = res[:fields]
          {% for key, value in properties %}
            {% unless value[:primary] && primary_auto_incrementable %}
              args << {% if value[:type].stringify == "JSON::Any" %}
                        (@{{key.id}} ? @{{key.id}}.to_json : nil)
                      {% else %}
                        @{{key.id}}
                      {% end %}
              fields << {{key.stringify}}
            {% end %}
          {% end %}

          { args: args, fields: fields }
        end

        def self.all
          ::Jennifer::QueryBuilder::ModelQuery({{@type}}).build(table_name).where { _type == {{@type.stringify}} }
        end

        private def __refresh_changes
          {% for key, value in properties %}
            @{{key.id}}_changed = false
          {% end %}
          super
        end

        macro finished
          ::Jennifer::Model::RelationDefinition.finished_hook
        end
      end

      macro sti_mapping(**properties)
        sti_mapping({{properties}})
      end
    end
  end
end
