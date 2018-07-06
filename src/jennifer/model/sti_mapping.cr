module Jennifer
  module Model
    module STIMapping
      # Defines mapping using single table inheritance. Is automatically called by `%mapping` macro.
      private macro sti_mapping(properties)
        STI = true

        def self.sti_condition
          c("type") == {{@type.id.stringify}}
        end

        def self.table_name
          superclass.table_name
        end

        def self.table_name(name)
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

        {% nonvirtual_attrs = properties.keys.select { |attr| !properties[attr][:virtual] } %}

        __field_declaration({{properties}}, false)

        def _sti_extract_attributes(values : Hash(String, ::Jennifer::DBAny))
          {% for key, value in properties %}
            %var{key.id} = {{value[:default]}}
            %found{key.id} = true
          {% end %}

          {% for key, value in properties %}
            {% column = (value[:column_name] || key).id.stringify %}
            if values.has_key?({{column}})
              %var{key.id} = values[{{column}}]{% if value[:numeric_converter] %}.as(PG::Numeric).{{value[:numeric_converter].id}}{% end %}
            else
              %found{key.id} = false
            end
          {% end %}

          {% for key, value in properties %}
            begin
              {% if value[:null] %}
                {% if value[:default] != nil %}
                  %casted_var{key.id} = %found{key.id} ? __bool_convert(%var{key.id}, {{value[:parsed_type].id}}) : {{value[:default]}}
                {% else %}
                  %casted_var{key.id} = %var{key.id}.as({{value[:parsed_type].id}})
                {% end %}
              {% elsif value[:default] != nil %}
                %casted_var{key.id} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : __bool_convert(%var{key.id}, {{value[:parsed_type].id}})
              {% else %}
                %casted_var{key.id} = __bool_convert(%var{key.id}, {{value[:parsed_type].id}})
              {% end %}
              %casted_var{key.id} = !%casted_var{key.id}.is_a?(Time) ? %casted_var{key.id} : %casted_var{key.id}.in(::Jennifer::Config.local_time_zone)
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.build({{key.id.stringify}}, {{@type}}, e)
            end
          {% end %}

          {% if properties.size > 1 %}
            {
            {% for key, value in properties %}
              %casted_var{key.id},
            {% end %}
            }
          {% else %}
            {% key = properties.keys[0] %}
            %casted_var{key}
          {% end %}
        end

        # creates object from db tuple
        def initialize(%pull : DB::ResultSet)
          initialize(self.class.adapter.result_to_hash(%pull), false)
        end

        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          initialize(stringify_hash(values, Jennifer::DBAny))
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny))
          # TODO: try to make the "type" field customizable
          values["type"] = "{{@type.id}}" if values["type"]?.nil?
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
          {% for key in nonvirtual_attrs %}
            @{{key.id}}_changed ||
          {% end %}
          false
        end

        def to_h
          hash = super
          {% for key in nonvirtual_attrs %}
            hash[:{{key.id}}] = @{{key.id}}
          {% end %}
          hash
        end

        def to_str_h
          hash = super
          {% for key in nonvirtual_attrs %}
            hash[{{key.stringify}}] = @{{key.id}}
          {% end %}
          hash
        end

        def update_columns(values : Hash(String | Symbol, Jennifer::DBAny))
          missing_values = {} of String | Symbol => Jennifer::DBAny
          values.each do |name, value|
            case name.to_s
            {% for key, value in properties %}
              {% if !value[:virtual] %}
                when "{{key.id}}"
                  if value.is_a?({{value[:parsed_type].id}})
                    local = value.as({{value[:parsed_type].id}})
                    @{{key.id}} = local
                    @{{key.id}}_changed = true
                  else
                    raise ::Jennifer::BaseException.new("Wrong type for #{name} : #{value.class}")
                  end
              {% end %}
            {% end %}
            else
              missing_values[name] = value
            end
          end
          super(missing_values)
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
          if raise_exception && !self.class.field_names.includes?(name)
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
            {% unless value[:virtual] %}
              if @{{key.id}}_changed
                args << {% if value[:stringified_type] =~ Jennifer::Macros::JSON_REGEXP %}
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
            {% unless value[:virtual] %}
              args << {% if value[:stringified_type] =~ Jennifer::Macros::JSON_REGEXP %}
                        (@{{key.id}} ? @{{key.id}}.to_json : nil)
                      {% else %}
                        @{{key.id}}
                      {% end %}
              fields << {{key.stringify}}
            {% end %}
          {% end %}

          { args: args, fields: fields }
        end

        def self.all : ::Jennifer::QueryBuilder::ModelQuery({{@type}})
          ::Jennifer::QueryBuilder::ModelQuery({{@type}}).build(table_name).where { _type == {{@type.stringify}} }
        end

        private def init_attributes(values : Hash)
          super(values)
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _sti_extract_attributes(values)
        end

        private def init_attributes(values : DB::ResultSet)
          init_attributes(self.class.adapter.result_to_hash(values))
        end

        private def __refresh_changes
          {% for key in nonvirtual_attrs %}
            @{{key.id}}_changed = false
          {% end %}
          super
        end

        {% all_properties = properties %}
        {% for key, value in @type.superclass.constant("COLUMNS_METADATA") %}
          {% if !properties[key] %}
            {% all_properties[key] = value %}
          {% end %}
        {% end %}

        COLUMNS_METADATA = {{all_properties}}
        PRIMARY_AUTO_INCREMENTABLE = {{@type.superclass.constant("PRIMARY_AUTO_INCREMENTABLE")}}
        FIELD_NAMES = [{{all_properties.keys.map { |e| "#{e.id.stringify}" }.join(", ").id}}]

        def self.columns_tuple
          COLUMNS_METADATA
        end

        def self.field_count
          {{all_properties.size}}
        end

        def self.field_names
          FIELD_NAMES
        end
      end
    end
  end
end
