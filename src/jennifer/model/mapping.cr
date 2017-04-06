module Jennifer
  module Model
    module Mapping
      macro mapping(properties, strict = true)
        @@field_names = [
          {% for key, v in properties %}
            "{{key.id}}",
          {% end %}
        ]

        def self.field_count
          {{properties.size}}
        end

        def self.field_names
          @@field_names
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
        {% end %}

        # creates getter and setters
        {% for key, value in properties %}
          {% t_string = properties[key][:type].stringify %}
          {% properties[key][:parsed_type] = properties[key][:null] || properties[key][:primary] ? t_string + "?" : t_string %}
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

            {% if primary && primary_auto_incrementable %}
              def init_primary_field(value : {{value[:type]}})
                raise "Primary field is already initialized" if @{{key.id}}
                @{{key.id}} = value
              end
            {% end %}
          {% end %}
        {% end %}

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
                %var{key.id} =
                  # if value[:type].is_a?(Path) || value[:type].is_a?(Generic)
                  {% if value[:type].stringify == "JSON::Any" %}
                    begin
                      %temp{key.id} = %pull.read
                      JSON.parse(%temp{key.id}.to_s) if %temp{key.id}
                    end
                  {% else %}
                    %pull.read({{value[:parsed_type].id}})
                  {% end %}
            {% end %}
            else
              {% if strict %}
                raise ::Jennifer::BaseException.new("Unknown column #{column}")
              {% else %}
                %pull.read
              {% end %}
            end
          end

          {% for key, value in properties %}
            @{{key.id}} = %var{key.id}.as({{value[:parsed_type].id}})
          {% end %}
        end

        def initialize(values : Hash | NamedTuple)
          {% for key, value in properties %}
            %var{key.id} = nil
            %found{key.id} = true
          {% end %}

          {% for key, value in properties %}
            if !values[:{{key.id}}]?.nil?
              %var{key.id} = values[:{{key.id}}]
            elsif !values["{{key.id}}"]?.nil?
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
          initialize({} of Symbol => DB::Any)
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

        def save(skip_validation = false)
          unless skip_validation
            validate!
            return false unless valid?
          end
          response =
            if new_record?
              res = ::Jennifer::Adapter.adapter.insert(self)
              {% if primary && primary_auto_incrementable %}
                if primary.nil? && res.last_insert_id > -1
                  init_primary_field(res.last_insert_id.to_i)
                end
              {% end %}
              @new_record = false if res.rows_affected != 0
              res
            else
              ::Jennifer::Adapter.adapter.update(self)
            end
          after_save_callback
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

        def attribute(name : String)
          case name
          {% for key, value in properties %}
          when "{{key.id}}"
            @{{key.id}}
          {% end %}
          else
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}")
          end
        end

        def attribute(name : Symbol)
          attribute(name.to_s)
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

        private def after_save_callback
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
