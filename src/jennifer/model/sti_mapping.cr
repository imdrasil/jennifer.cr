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

        # NOTE: next section is a copy-paste from mapping.cr (with removing any parsing of primary option)
        {% add_default_constructor = @type.superclass.constant("WITH_DEFAULT_CONSTRUCTOR") %}

        # generates hash with options
        {% for key, value in properties %}
          {% unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
            {% properties[key] = {type: value} %}
          {% end %}
          {% properties[key][:stringified_type] = properties[key][:type].stringify %}
          {% if properties[key][:stringified_type] =~ Jennifer::Macros::NILLABLE_REGEXP %}
            {%
              properties[key][:null] = true
              properties[key][:parsed_type] = properties[key][:stringified_type]
            %}
          {% else %}
            {% properties[key][:parsed_type] = properties[key][:null] ? properties[key][:stringified_type] + "?" : properties[key][:stringified_type] %}
          {% end %}
          {% add_default_constructor = add_default_constructor && (properties[key][:null] || properties[key].keys.includes?(:default)) %}
        {% end %}

        __field_declaration({{properties}}, false)

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
          # TODO: try to make the "type" field customizable
          values["type"] = "{{@type.id}}"
          super(values)
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _sti_extract_attributes(values)
        end

        def initialize(values : Hash | NamedTuple, @new_record)
          initialize(values)
        end

        {% if add_default_constructor %}
          WITH_DEFAULT_CONSTRUCTOR = true

          def initialize
            initialize({} of String => ::Jennifer::DBAny)
          end
        {% else %}
          WITH_DEFAULT_CONSTRUCTOR = false
        {% end %}

        def changed?
          super ||
          {% for key in properties.keys %}
            @{{key.id}}_changed ||
          {% end %}
          false
        end

        def to_h
          hash = super
          {% for key in properties.keys %}
            hash[:{{key.id}}] = @{{key.id}}
          {% end %}
          hash
        end

        def to_str_h
          hash = super
          {% for key in properties.keys %}
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
                raise ::Jennifer::BaseException.new("Wrong type for #{name} : #{value.class}")
              end
            {% end %}
            end
          end

          super
        end

        def set_attribute(name, value)
          case name.to_s
          {% for key, value in properties %}
            {% if value[:setter] != false %}
              when "{{key.id}}"
                if value.is_a?({{value[:parsed_type].id}})
                  self.{{key.id}} = value.as({{value[:parsed_type].id}})
                else
                  raise ::Jennifer::BaseException.new("Wrong type for #{name} : #{value.class}")
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

        def arguments_to_save
          res = super
          args = res[:args]
          fields = res[:fields]
          {% for key, value in properties %}
            if @{{key.id}}_changed
              args << {% if value[:stringified_type] =~ Jennifer::Macros::JSON_REGEXP %}
                        @{{key.id}}.to_json
                      {% else %}
                        @{{key.id}}
                      {% end %}
              fields << "{{key.id}}"
            end
          {% end %}
          {args: args, fields: fields}
        end

        def arguments_to_insert
          res = super
          args = res[:args]
          fields = res[:fields]
          {% for key, value in properties %}
            args << {% if value[:stringified_type] =~ Jennifer::Macros::JSON_REGEXP %}
                      (@{{key.id}} ? @{{key.id}}.to_json : nil)
                    {% else %}
                      @{{key.id}}
                    {% end %}
            fields << {{key.stringify}}
          {% end %}

          { args: args, fields: fields }
        end

        def self.all
          ::Jennifer::QueryBuilder::ModelQuery({{@type}}).build(table_name).where { _type == {{@type.stringify}} }
        end

        private def __refresh_changes
          {% for key in properties.keys %}
            @{{key.id}}_changed = false
          {% end %}
          super
        end

        {% all_properties = properties %}
        {% for key, value in @type.superclass.constant("COLUMNS_METADATA") %}
          {% all_properties[key] = value %}
        {% end %}

        COLUMNS_METADATA = {{all_properties}}
        PRIMARY_AUTO_INCREMENTABLE = {{@type.superclass.constant("PRIMARY_AUTO_INCREMENTABLE")}}

        def self.columns_tuple
          COLUMNS_METADATA
        end

        def self.field_count
          {{all_properties.size}}
        end

        def self.field_names
          [
            {% for key in all_properties.keys %}
              "{{key.id}}",
            {% end %}
          ]
        end
      end

      macro sti_mapping(**properties)
        sti_mapping({{properties}})
      end
    end
  end
end
