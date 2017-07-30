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
              def init_primary_field(value : {{value[:type]}})
                raise "Primary field is already initialized" if @{{key.id}}
                @{{key.id}} = value
              end
            {% end %}
          {% end %}
        {% end %}
      end

      macro with_timestamps
        after_create :__update_created_at
        after_save :__update_updated_at

        def __update_created_at
          @created_at = Time.now
        end

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
              [] of Model::Base
            {% end %}
          {% end %}
        end

        FIELD_NAMES = [
          {% for key, v in properties %}
            "{{key.id}}",
          {% end %}
        ]

        def self.field_count
          {{properties.size}}
        end

        def self.field_names
          FIELD_NAMES
        end

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
        {% end %}

        __field_declaration({{properties}}, {{primary_auto_incrementable}})

        def self.primary_auto_incrementable?
          {{primary_auto_incrementable}}
        end

        @new_record = true

        # creates object from db tuple
        def initialize(%pull : DB::ResultSet)
          @new_record = false
          {% for key, value in properties %}
            %var{key.id} = nil
            %found{key.id} = false
          {% end %}

          {{properties.size}}.times do |i|
            column = %pull.column_name(%pull.column_index)
            case column
            {% for key, value in properties %}
              when {{value[:column_name] || key.id.stringify}}
                %found{key.id} = true
                %var{key.id} = %pull.read({{value[:parsed_type].id}})
                # if value[:type].is_a?(Path) || value[:type].is_a?(Generic)
            {% end %}
            else
              {% if strict %}
                raise ::Jennifer::BaseException.new("Undefined column #{column}")
              {% else %}
                %pull.read
              {% end %}
            end
          end

          {% for key, value in properties %}
            @{{key.id}} = %var{key.id}.as({{value[:parsed_type].id}})
          {% end %}
        end

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

        def initialize(**values)
          initialize(values)
        end

        def initialize
          initialize({} of Symbol => DBAny)
        end

        def new_record?
          @new_record
        end

        def self.create(values : Hash | NamedTuple)
          o = new(values)
          o.save
          o
        end

        def self.create
          a = {} of Symbol => Supportable
          o = new(a)
          o.save
          o
        end

        def self.create(**values)
          o = new(values.to_h)
          o.save
          o
        end

        def self.create!(values : Hash | NamedTuple)
          o = new(values)
          o.save!
          o
        end

        def self.create!
          o = new({} of Symbol => Supportable)
          o.save!
          o
        end

        def self.create!(**values)
          o = new(values.to_h)
          o.save!
          o
        end

        def save!(skip_validation = false)
          raise Jennifer::BaseException.new("Record was not save") unless save(skip_validation)
          true
        end

        def save(skip_validation = false)
          unless skip_validation
            validate!
            return false unless valid?
          end
          __before_save_callback
          response =
            if new_record?
              __before_create_callback
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

        def changed?
          {% for key, value in properties %}
            @{{key.id}}_changed ||
          {% end %}
          false
        end

        def to_h
          {
            {% for key, value in properties %}
              :{{key.id}} => @{{key.id}},
            {% end %}
          }
        end

        def to_str_h
          {
            {% for key, value in properties %}
              {{key.stringify}} => @{{key.id}},
            {% end %}
          }
        end

        def update_column(name, value : Jennifer::DBAny)
          update_columns({name => value})
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
            else
              raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}")
            end
          end

          _primary = self.class.primary
          _primary_value = primary
          ::Jennifer::Adapter.adapter.update(self.class.all.where { _primary == _primary_value }, values)
        end

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
          {
            args: [
              {% for key, value in properties %}
                {% unless value[:primary] && primary_auto_incrementable %}
                  {% if value[:type].stringify == "JSON::Any" %}
                     (@{{key.id}} ? @{{key.id}}.to_json : nil),
                  {% else %}
                    @{{key.id}},
                  {% end %}
                {% end %}
              {% end %}
            ],
            fields: [
              {% for key, value in properties %}
                {% unless value[:primary] && primary_auto_incrementable %}
                  "{{key.id}}",
                {% end %}
              {% end %}
            ]
          }
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

      macro sti_mapping(properties)
        def self.sti_condition
          c("type") == "{{@type.id}}"
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

        # creates object from db tuple
        def initialize(%pull : DB::ResultSet)
          initialize(::Jennifer::Adapter.adapter.result_to_hash(%pull), false)
        end

        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          initialize(stringify_hash(values, Jennifer::DBAny))
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny))
          values["type"] = "{{@type.id}}" if values.is_a?(Hash)
          super
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
                @{{key.id}} = %found{key.id} ? %var{key.id}.as({{value[:parsed_type].id}}) : {{value[:default]}}
              {% else %}
                @{{key.id}} = %var{key.id}.as({{value[:parsed_type].id}})
              {% end %}
            {% elsif value[:default] != nil %}
              @{{key.id}} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : %var{key.id}.as({{value[:parsed_type].id}})
            {% else %}
              @{{key.id}} = (%var{key.id}).as({{value[:parsed_type].id}})
            {% end %}
          {% end %}
        end

        def initialize(values : Hash | NamedTuple, @new_record)
          initialize(values)
        end

        def initialize(**values)
          initialize(values)
        end

        def initialize
          initialize({} of Symbol => DB::Any)
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
