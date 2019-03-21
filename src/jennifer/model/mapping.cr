module Jennifer
  module Model
    module Mapping
      # :nodoc:
      macro __bool_convert(value, type)
        {% if type.stringify == "Bool" %}
          ({{value.id}}.is_a?(Int8) ? {{value.id}} == 1i8 : {{value.id}}.as({{type}}))
        {% else %}
          {{value}}.as({{type}})
        {% end %}
      end

      # TODO: remove .primary_field_type method as it isn't used anywhere

      # :nodoc:
      macro __field_declaration(properties, primary_auto_incrementable)
        {% for key, value in properties %}
          @{{key.id}} : {{value[:parsed_type].id}}
          @[JSON::Field(ignore: true)]
          @{{key.id}}_changed = false

          {% if value[:setter] != false %}
            def {{key.id}}=(_{{key.id}} : {{value[:parsed_type].id}})
              {% if !value[:virtual] %}
                @{{key.id}}_changed = true if _{{key.id}} != @{{key.id}}
              {% end %}
              @{{key.id}} = _{{key.id}}
            end

            def {{key.id}}=(_{{key.id}} : ::Jennifer::DBAny)
              {% if !value[:virtual] %}
                @{{key.id}}_changed = true if _{{key.id}} != @{{key.id}}
              {% end %}
              @{{key.id}} = _{{key.id}}.as({{value[:parsed_type].id}})
            end
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

            def self._{{key}}
              c({{value[:column]}})
            end

            {% if value[:primary] %}
              # :nodoc:
              def primary
                @{{key.id}}
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
              def self.primary_field_type
                {{value[:parsed_type].id}}
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

      # :nodoc:
      macro build_properties(properties)
        {%
          new_props = properties.to_a.reduce({} of ASTNode => ASTNode) do |hash, (key, value)|
            hash[key] = value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) ? value : {type: value}
            options = hash[key]

            if options[:type].is_a?(Path) && TYPES.includes?(options[:type].stringify)
              options[:type].resolve.map do |tkey, tvalue|
                options[tkey] = tvalue if tkey == :type || options[tkey] == nil
              end
            end

            stringified_type = options[:type].stringify
            options[:converter] = ::Jennifer::Model::JSONConverter if stringified_type =~ Jennifer::Macros::JSON_REGEXP && options[:converter] == nil
            options[:parsed_type] = stringified_type

            options[:column] = (options[:column] || key).id.stringify

            if stringified_type =~ NILLABLE_REGEXP
              options[:null] = true
            elsif options[:null] || options[:primary]
              options[:parsed_type] = stringified_type + "?"
            end

            hash
          end
        %}

        # :nodoc:
        COLUMNS_METADATA = { {{new_props.map { |field, mapping| "#{field}: #{mapping}" }.join(", ").id }} }
      end

      # Adds callbacks for `created_at` and `updated_at` fields
      macro with_timestamps(created_at = true, updated_at = true)
        {% if created_at %}
          before_save :__update_updated_at

          # :nodoc:
          def __update_created_at
            @created_at = Time.new(Jennifer::Config.local_time_zone)
          end
        {% end %}

        {% if updated_at %}
          before_create :__update_created_at

          # :nodoc:
          def __update_updated_at
            @updated_at = Time.new(Jennifer::Config.local_time_zone)
          end
        {% end %}
      end

      # :nodoc:
      macro common_mapping(strict)
        {%
          primary = COLUMNS_METADATA.keys.find { |field| COLUMNS_METADATA[field][:primary] }
          primary_auto_incrementable = primary && AUTOINCREMENTABLE_STR_TYPES.includes?(COLUMNS_METADATA[primary][:type].stringify)
          properties = COLUMNS_METADATA
          nonvirtual_attrs = properties.keys.select { |attr| !properties[attr][:virtual] }
          raise "Model #{@type} has no defined primary field. For now model without primary field is not allowed" if primary == nil
        %}

        __field_declaration({{properties}}, {{primary_auto_incrementable}})

        # :nodoc:
        def self.field_count
          {{properties.size}}
        end

        # :nodoc:
        FIELD_NAMES = [{{properties.keys.map { |e| "#{e.id.stringify}" }.join(", ").id}}]

        # :nodoc:
        def self.field_names
          FIELD_NAMES
        end

        # :nodoc:
        def self.columns_tuple
          COLUMNS_METADATA
        end

        @[JSON::Field(ignore: true)]
        @new_record = true
        @[JSON::Field(ignore: true)]
        @destroyed = false

        # Creates object from `DB::ResultSet`
        def initialize(%pull : DB::ResultSet)
          @new_record = false
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(%pull)
        end

        # :nodoc:
        def self.new(pull : DB::ResultSet)
          {% verbatim do %}
          {% begin %}
            {% klasses = @type.all_subclasses.select { |s| s.constant("STI") == true } %}
            {% if !klasses.empty? %}
              hash = adapter.result_to_hash(pull)
              case hash["type"]
              when "", nil, "{{@type}}"
                new(hash, false)
              {% for klass in klasses %}
              when "{{klass}}"
                {{klass}}.new(hash, false)
              {% end %}
              else
                raise ::Jennifer::UnknownSTIType.new(self, hash["type"])
              end
            {% else %}
              instance = allocate
              instance.initialize(pull)
              instance.__after_initialize_callback
              instance
            {% end %}
          {% end %}
          {% end %}
        end

        # Accepts symbol hash or named tuple, stringify it and calls constructor with string-based keys hash.
        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          initialize(Ifrit.stringify_hash(values, Jennifer::DBAny))
        end

        # :nodoc:
        def self.new(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          instance = allocate
          instance.initialize(values)
          instance.__after_initialize_callback
          instance
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny))
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        # :nodoc:
        def self.new(values : Hash(String, ::Jennifer::DBAny))
          instance = allocate
          instance.initialize(values)
          instance.__after_initialize_callback
          instance
        end

        # :nodoc:
        def initialize(values : Hash | NamedTuple, @new_record)
          initialize(values)
        end

        # :nodoc:
        def self.new(values : Hash | NamedTuple, new_record : Bool)
          instance = allocate
          instance.initialize(values, new_record)
          instance.__after_initialize_callback
          instance
        end

        # :nodoc:
        def to_h
          {
            {% for key in nonvirtual_attrs %}
              :{{key.id}} => {{key.id}},
            {% end %}
          } of Symbol => ::Jennifer::DBAny
        end

        # :nodoc:
        def to_str_h
          {
            {% for key in nonvirtual_attrs %}
              {{key.stringify}} => {{key.id}},
            {% end %}
          } of String => ::Jennifer::DBAny
        end

        # :nodoc:
        def attribute(name : String | Symbol, raise_exception : Bool = true)
          case name.to_s
          {% for attr in properties.keys %}
          when "{{attr.id}}"
            @{{attr.id}}
          {% end %}
          else
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}") if raise_exception
          end
        end

        private def init_attributes(values : Hash)
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        private def init_attributes(values : DB::ResultSet)
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        private def inspect_attributes(io) : Nil
          io << ' '
          {% for var, i in properties.keys %}
            {% if i > 0 %} io << ", " {% end %}
            io << "{{var.id}}: "
            @{{var.id}}.inspect(io)
          {% end %}
          nil
        end
      end

      # :nodoc:
      macro base_mapping(strict = true)
        {%
          primary = COLUMNS_METADATA.keys.find { |field| COLUMNS_METADATA[field][:primary] }
          primary_auto_incrementable = primary && AUTOINCREMENTABLE_STR_TYPES.includes?(COLUMNS_METADATA[primary][:type].stringify)
          add_default_constructor = COLUMNS_METADATA.keys.all? do|field|
            options = COLUMNS_METADATA[field]

            options[:primary] || options[:null] || options.keys.includes?(:default.id)
          end
          properties = COLUMNS_METADATA
          nonvirtual_attrs = properties.keys.select { |attr| !properties[attr][:virtual] }
        %}

        common_mapping({{strict}})

        # :nodoc:
        WITH_DEFAULT_CONSTRUCTOR = {{!!add_default_constructor}}

        # :nodoc:
        def self.primary_auto_incrementable?
          {{primary_auto_incrementable}}
        end

        {% if add_default_constructor %}
          def self.new
            instance = {{@type}}.allocate
            instance.initialize
            instance.__after_initialize_callback
            instance
          end

          # Default constructor without any fields
          def initialize
            {% for key, value in properties %}
              @{{key.id}} = {{ value[:default] }}
            {% end %}
          end

          # :nodoc:
          def self.build
            new
          end
        {% end %}

        # :nodoc:
        def destroy
          return false if new_record?
          result =
            unless self.class.adapter.under_transaction?
              self.class.transaction do
                destroy_without_transaction
              end
            else
              destroy_without_transaction
            end
          if result
            self.class.adapter.subscribe_on_commit(->__after_destroy_commit_callback) if HAS_DESTROY_COMMIT_CALLBACK
            self.class.adapter.subscribe_on_rollback(->__after_destroy_rollback_callback) if HAS_DESTROY_ROLLBACK_CALLBACK
          end
          result
        end

        # :nodoc:
        def changed?
          {% for attr in nonvirtual_attrs %}
            @{{attr.id}}_changed ||
          {% end %}
          false
        end

        # :nodoc:
        def update_columns(values : Hash(String | Symbol, ::Jennifer::DBAny))
          values.each do |name, value|
            case name.to_s
            {% for key, value in properties %}
              {% if !value[:virtual] %}
                when "{{key.id}}" {% if key.id.stringify != value[:column] %}, {{value[:column]}} {% end %}
                  if value.is_a?({{value[:parsed_type].id}})
                    local = value.as({{value[:parsed_type].id}})
                    @{{key.id}} = local
                    @{{key.id}}_changed = true
                  else
                    raise ::Jennifer::BaseException.new("Wrong type for #{self.class}##{name} : #{value.class}")
                  end
              {% end %}
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown model attribute - #{self.class}##{name}")
            end
          end

          self.class.adapter.update(self)
          __refresh_changes
        end

        # :nodoc:
        def set_attribute(name : String | Symbol, value : Jennifer::DBAny)
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

        # :nodoc:
        def arguments_to_save
          args = [] of ::Jennifer::DBAny
          fields = [] of String
          {% for attr in nonvirtual_attrs %}
            {% options = properties[attr] %}
            {% unless options[:primary] %}
              if @{{attr.id}}_changed
                args <<
                  {% if options[:converter] %} {{options[:converter]}}.to_db(@{{attr.id}}) {% else %} @{{attr.id}} {% end %}
                fields << {{options[:column]}}
              end
            {% end %}
          {% end %}
          {args: args, fields: fields}
        end

        # :nodoc:
        def arguments_to_insert
          args = [] of ::Jennifer::DBAny
          fields = [] of String
          {% for attr, options in properties %}
            {% unless options[:virtual] || options[:primary] && primary_auto_incrementable %}
              args <<
                {% if options[:converter] %} {{options[:converter]}}.to_db(@{{attr.id}}) {% else %} @{{attr.id}} {% end %}
              fields << {{options[:column]}}
            {% end %}
          {% end %}
          {args: args, fields: fields}
        end

        # Extracts arguments due to mapping from *pull* and returns tuple for fields assignment.
        # It stands on that fact result set has all defined fields in a row
        # TODO: think about moving it to class scope
        # NOTE: don't use it manually - there is some dependencies on caller such as reading result set to the end
        # if exception was raised
        private def _extract_attributes(pull : DB::ResultSet)
          requested_columns_count = self.class.actual_table_field_count
          ::Jennifer::BaseException.assert_column_count(requested_columns_count, pull.column_count)
          {% for key, value in properties %}
            %var{key.id} = {{value[:default]}}
            %found{key.id} = false
          {% end %}
          requested_columns_count.times do
            column = pull.column_name(pull.column_index)
            case column
            {% for key in nonvirtual_attrs %}
              {% value = properties[key] %}
              when {{value[:column]}}
                %found{key.id} = true
                begin
                  %var{key.id} =
                    {% if value[:converter] %}
                      {{ value[:converter] }}.from_db(pull, {{value[:null]}})
                    {% else %}
                      pull.read({{value[:parsed_type].id}})
                    {% end %}
                  %var{key.id} = %var{key.id}.in(::Jennifer::Config.local_time_zone) if %var{key.id}.is_a?(Time)
                rescue e : Exception
                  raise ::Jennifer::DataTypeMismatch.build(column, {{@type}}, e)
                end
            {% end %}
            else
              {% if strict %}
                raise ::Jennifer::BaseException.new("Undefined column #{column} for model {{@type}}.")
              {% else %}
                pull.read
              {% end %}
            end
          end
          {% if strict %}
            {% for key in nonvirtual_attrs %}
              unless %found{key.id}
                raise ::Jennifer::BaseException.new("Column {{@type}}.{{properties[key][:column].id}} hasn't been found in the result set.")
              end
            {% end %}
          {% end %}
          {% if properties.size > 1 %}
            {
            {% for key, value in properties %}
              begin
                %var{key.id}.as({{value[:parsed_type].id}})
              rescue e : Exception
                raise ::Jennifer::DataTypeCasting.build({{value[:column]}}, {{@type}}, e)
              end,
            {% end %}
            }
          {% else %}
            {% key = properties.keys[0] %}
            begin
              %var{key}.as({{properties[key][:parsed_type].id}})
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.build({{properties[key][:column]}}, {{@type}}, e)
            end
          {% end %}
        end

        private def _extract_attributes(values : Hash(String, ::Jennifer::DBAny))
          {% for key, value in properties %}
            %var{key.id} = {{value[:default]}}
            %found{key.id} = true
          {% end %}

          {% for key, value in properties %}
            {% column1 = key.id.stringify %}
            {% column2 = value[:column] %}
            if values.has_key?({{column1}})
                %var{key.id} =
                  {% if value[:converter] %}
                    {{value[:converter]}}.from_hash(values, {{column1}})
                  {% else %}
                    values[{{column1}}]
                  {% end %}
            elsif values.has_key?({{column2}})
                %var{key.id} =
                {% if value[:converter] %}
                  {{value[:converter]}}.from_hash(values, {{column2}})
                {% else %}
                  values[{{column2}}]
                {% end %}
            else
              %found{key.id} = false
            end
          {% end %}

          {% for key, value in properties %}
            begin
              %casted_var{key.id} =
                {% if value[:default] != nil %}
                  %found{key.id} ? __bool_convert(%var{key.id}, {{value[:parsed_type].id}}) : {{value[:default]}}
                {% else %}
                  __bool_convert(%var{key.id}, {{value[:parsed_type].id}})
                {% end %}
              %casted_var{key.id} = %casted_var{key.id}.in(::Jennifer::Config.local_time_zone) if %casted_var{key.id}.is_a?(Time)
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.match?(e) ? ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) : e
            end
          {% end %}

          {% if properties.size > 1 %}
            {
            {% for key, value in properties %}
              %casted_var{key.id},
            {% end %}
            }
          {% else %}
            %casted_var{properties.keys[0]}
          {% end %}
        end

        private def __refresh_changes
          {% for attr in nonvirtual_attrs %}
            @{{attr.id}}_changed = false
          {% end %}
        end

        private def save_record_under_transaction(skip_validation) : Bool
          is_new_record = new_record?
          return false unless save_without_transaction(skip_validation)
          if is_new_record
            self.class.adapter.subscribe_on_commit(->__after_create_commit_callback) if HAS_CREATE_COMMIT_CALLBACK
            self.class.adapter.subscribe_on_rollback(->__after_create_rollback_callback) if HAS_CREATE_ROLLBACK_CALLBACK
          else
            self.class.adapter.subscribe_on_commit(->__after_update_commit_callback) if HAS_CREATE_COMMIT_CALLBACK
            self.class.adapter.subscribe_on_rollback(->__after_update_rollback_callback) if HAS_CREATE_ROLLBACK_CALLBACK
          end
          self.class.adapter.subscribe_on_commit(->__after_save_commit_callback) if HAS_SAVE_COMMIT_CALLBACK
          self.class.adapter.subscribe_on_rollback(->__after_save_rollback_callback) if HAS_SAVE_ROLLBACK_CALLBACK
          true
        end

        macro inherited
          # :nodoc:
          MODEL = true
        end
      end

      # Defines model mapping.
      #
      # For the detailed description take a look at `.md` documentation file.
      #
      # Acceptable keys:
      # - type
      # - getter
      # - setter
      # - null
      # - primary
      # - virtual
      # - default
      # - converter
      # - column
      macro mapping(properties, strict = true)
        build_properties({{properties}})
        {% if !@type.constant("MODEL") %}
          base_mapping({{strict}})
        {% else %}
          sti_mapping
        {% end %}
      end

      # ditto
      macro mapping(**properties)
        mapping({{properties}})
      end
    end
  end
end
