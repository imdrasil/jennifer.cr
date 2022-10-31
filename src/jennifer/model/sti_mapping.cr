module Jennifer
  module Model
    # :nodoc:
    module STIMapping
      # Defines mapping using single table inheritance. Is automatically called by `.mapping` macro.
      private macro sti_mapping
        # :nodoc:
        STI = true

        def self.sti_condition
          c("type") == {{@type.id.stringify}}
        end

        # :nodoc:
        def self.table_name
          superclass.table_name
        end

        # :nodoc:
        def self.table_name(name)
          raise "You can't specify table name using STI on subclasses"
        end

        {%
          super_properties = INHERITED_COLUMNS_METADATA
          add_default_constructor =
            super_properties.keys.all? do |field|
              options = super_properties[field]

              options[:null] || options.keys.includes?(:default.id) || field == :type
            end &&
              COLUMNS_METADATA.keys.all? do |field|
                options = COLUMNS_METADATA[field]

                options[:null] || options.keys.includes?(:default.id)
              end
          properties = COLUMNS_METADATA
          nonvirtual_attrs = properties.keys.select { |attr| !properties[attr][:virtual] }

          all_properties = super_properties.to_a.reduce({} of ASTNode => ASTNode) do |hash, (key, value)|
            hash[key] = value
            hash
          end
          properties.to_a.reduce(all_properties) do |hash, (key, value)|
            hash[key] = value
            hash
          end
        %}

        __field_declaration({{properties}}, false)

        private def _extract_attributes(pull : DB::ResultSet)
          requested_columns_count = self.class.actual_table_field_count
          ::Jennifer::BaseException.assert_column_count(requested_columns_count, pull.column_count)
          {% for key, value in all_properties %}
            %var{key.id} = {{value[:default]}}
            %found{key.id} = false
          {% end %}
          requested_columns_count.times do
            column = pull.column_name(pull.column_index)
            case column
            {% for key, value in all_properties %}
              {% if !value[:virtual] %}
              when {{value[:column]}}
                %found{key.id} = true
                begin
                  %var{key.id} =
                    {% if value[:converter] %}
                      {{ value[:converter] }}.from_db(pull, self.class.columns_tuple[:{{key.id}}])
                    {% else %}
                      pull.read({{value[:parsed_type].id}})
                    {% end %}
                rescue e : Exception
                  raise ::Jennifer::DataTypeMismatch.build(column, {{@type}}, e)
                end
              {% end %}
            {% end %}
            else
              pull.read
            end
          end
          {% if all_properties.size > 1 %}
            {
            {% for key, value in all_properties %}
              begin
                %var{key.id}.as({{value[:parsed_type].id}})
              rescue e : Exception
                raise ::Jennifer::DataTypeCasting.build({{value[:column]}}, {{@type}}, e)
              end,
            {% end %}
            }
          {% else %}
            {% key = all_properties.keys[0] %}
            begin
              %var{key}.as({{all_properties[key][:parsed_type].id}})
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.build({{all_properties[key][:column]}}, {{@type}}, e)
            end
          {% end %}
        end

        private def _extract_attributes(values : Hash(String, ::Jennifer::DBAny))
          {% for key, value in all_properties %}
            %var{key.id} = {{value[:default]}}
            %found{key.id} = true
          {% end %}

          {% for key, value in all_properties %}
            {% column1 = key.id.stringify %}
            {% column2 = value[:column] %}
            if values.has_key?({{column1}})
              %var{key.id} =
                {% if value[:converter] %}
                  {{value[:converter]}}.from_hash(values, {{column1}}, self.class.columns_tuple[:{{key.id}}])
                {% else %}
                  {{@type}}.read_adapter.coerce_database_value(values[{{column1}}], {{value[:type]}})
                {% end %}
            elsif values.has_key?({{column2}})
              %var{key.id} =
                {% if value[:converter] %}
                  {{value[:converter]}}.from_hash(values, {{column2}}, self.class.columns_tuple[:{{key.id}}])
                {% else %}
                  {{@type}}.read_adapter.coerce_database_value(values[{{column2}}], {{value[:type]}})
                {% end %}
            else
              %found{key.id} = false
            end
          {% end %}

          {% for key, value in all_properties %}
            begin
              %casted_var{key.id} =
                {% if value[:default] != nil %}
                  %found{key.id} ? %var{key.id}.as({{value[:parsed_type].id}}) : {{value[:default]}}
                {% else %}
                  %var{key.id}.as({{value[:parsed_type].id}})
                {% end %}
            rescue e : Exception
              raise e unless ::Jennifer::DataTypeCasting.match?(e)
              raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e)
            end
          {% end %}

          {% if all_properties.size > 1 %}
            {
            {% for key, value in all_properties %}
              %casted_var{key.id},
            {% end %}
            }
          {% else %}
            %casted_var{all_properties.keys[0]}
          {% end %}
        end

        def self.new(values : DB::ResultSet)
          instance = allocate
          instance.initialize(values)
          instance.__after_initialize_callback
          instance
        end

        # Creates object from db tuple
        def initialize(%pull : DB::ResultSet)
          @new_record = false
          {{all_properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(%pull)
        end

        def self.new(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple, new_record = true)
          instance = allocate
          instance.initialize(values, new_record)
          instance.__after_initialize_callback
          instance
        end

        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple, @new_record)
          initialize(Ifrit.stringify_hash(values, Jennifer::DBAny), @new_record)
        end

        def self.new(values : Hash(String, ::Jennifer::DBAny), new_record = true)
          instance = allocate
          instance.initialize(values, new_record)
          instance.__after_initialize_callback
          instance
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny), @new_record)
          values["type"] = "{{@type.id}}" if values["type"]?.nil?
          {{all_properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        # :nodoc:
        WITH_DEFAULT_CONSTRUCTOR = {{!!add_default_constructor}}

        {% if add_default_constructor %}
          def initialize
            initialize({ "type" => {{@type.stringify}} } of String => ::Jennifer::DBAny, true)
          end
        {% end %}

        # :nodoc:
        def changed?
          super ||
          {% for key in nonvirtual_attrs %}
            @{{key.id}}_changed ||
          {% end %}
          false
        end

        # :nodoc:
        def to_h
          hash = super
          {% for key in nonvirtual_attrs %}
            hash[:{{key.id}}] = {{key.id}}
          {% end %}
          hash
        end

        # :nodoc:
        def to_str_h
          hash = super
          {% for key in nonvirtual_attrs %}
            hash[{{key.stringify}}] = {{key.id}}
          {% end %}
          hash
        end

        # :nodoc:
        def update_columns(values : Hash(String | Symbol, ::Jennifer::DBAny))
          missing_values = {} of String | Symbol => Jennifer::DBAny
          values.each do |name, value|
            case name.to_s
            {% for key, value in properties %}
              {% if !value[:virtual] %}
                when {{value[:column]}}
                  if value.is_a?({{value[:parsed_type].id}})
                    @{{key.id}} = value.as({{value[:parsed_type].id}})
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

        # :nodoc:
        def set_attribute(name : String | Symbol, value : AttrType)
          case name.to_s
          {% for key, value in properties %}
            {% if value[:setter] != false %}
              when "{{key.id}}"
                if value.is_a?({{value[:parsed_type].id}}) || value.is_a?(String)
                  self.{{key.id}} = value
                else
                  raise ::Jennifer::BaseException.new("Wrong type for #{name} : #{value.class}")
                end
            {% end %}
          {% end %}
          else
            super
          end
        end

        # :nodoc:
        def attribute(name : String | Symbol, raise_exception = true)
          case name.to_s
          {% for key, value in properties %}
          when "{{key.id}}"
            self.{{key.id}}
          {% end %}
          else
            super
          end
        end

        # :nodoc:
        def attribute_before_typecast(name : String | Symbol) : ::Jennifer::DBAny
          case name.to_s
          {% for attr, options in properties %}
          when "{{attr.id}}"
            {% if options[:converter] %}
              {{options[:converter]}}.to_db(self.{{attr.id}}, self.class.columns_tuple[:{{attr.id}}])
            {% else %}
              self.{{attr.id}}
            {% end %}
          {% end %}
          else
            super
          end
        end

        # :nodoc:
        def arguments_to_insert
          named_tuple = super
          args = named_tuple[:args]
          fields = named_tuple[:fields]
          {% for attr, options in properties %}
            {% unless options[:virtual] %}
              args << attribute_before_typecast("{{attr}}")
              fields << {{options[:column]}}
            {% end %}
          {% end %}
          named_tuple
        end

        # :nodoc:
        def changes_before_typecast : Hash(String, ::Jennifer::DBAny)
          hash = super
          {% for attr, options in properties %}
            {% unless options[:virtual] || options[:generated] %}
              hash[{{options[:column]}}] = attribute_before_typecast("{{attr}}") if @{{attr.id}}_changed
            {% end %}
          {% end %}
          hash
        end

        # :nodoc:
        def self.all : ::Jennifer::QueryBuilder::ModelQuery({{@type}})
          ::Jennifer::QueryBuilder::ModelQuery({{@type}}).build(table_name, adapter).where { {{@type}}.sti_condition }
        end

        private def init_attributes(values : Hash)
          # ameba:disable Lint/ShadowingOuterLocalVar
          {{all_properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        private def init_attributes(values : DB::ResultSet)
          # ameba:disable Lint/ShadowingOuterLocalVar
          {{all_properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        private def __refresh_changes
          {% for key in nonvirtual_attrs %}
            @{{key.id}}_changed = false
          {% end %}
          super
        end

        {% for key, value in @type.superclass.constant("COLUMNS_METADATA") %}
          {% properties[key] = value if !properties[key] %}
        {% end %}

        # :nodoc:
        PRIMARY_AUTO_INCREMENTABLE = {{@type.superclass.constant("PRIMARY_AUTO_INCREMENTABLE")}}
        # :nodoc:
        FIELD_NAMES = [{{properties.keys.map { |e| "#{e.id.stringify}" }.join(", ").id}}]

        # :nodoc:
        def self.columns_tuple
          COLUMNS_METADATA
        end

        # :nodoc:
        def self.field_count : Int32
          {{properties.size}}
        end

        # :nodoc:
        def self.field_names : Array(String)
          [{{properties.keys.map { |e| "#{e.id.stringify}" }.join(", ").id}}]
        end

        # :nodoc:
        def self.column_names : Array(String)
          [{{all_properties.keys.select { |attr| !all_properties[attr][:virtual] }.map { |e| "#{e.id.stringify}" }.join(", ").id}}]
        end
      end
    end
  end
end
