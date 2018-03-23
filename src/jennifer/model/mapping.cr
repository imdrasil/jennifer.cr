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

      # :nodoc:
      # Generates getter and setters
      macro __field_declaration(properties, primary_auto_incrementable)
        {% for key, value in properties %}
          @{{key.id}} : {{value[:parsed_type].id}}
          @{{key.id}}_changed = false

          {% if value[:setter] != false %}
            def {{key.id}}=(_{{key.id}} : {{value[:parsed_type].id}})
              {% if !value[:virtual] %}
                @{{key.id}}_changed = true if _{{key.id}} != @{{key.id}}
              {% end %}
              @{{key.id}} = _{{key.id}}
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
          {% end %}

          {% if !value[:virtual] %}
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
                {{value[:parsed_type].id}}
              end

              # Inits primary field
              def init_primary_field(value)
                {% if primary_auto_incrementable %}
                  raise ::Jennifer::AlreadyInitialized.new(@{{key.id}}, value) if @{{key.id}}
                  @{{key.id}} = value.as({{value[:type]}})
                {% end %}
              end
            {% end %}
          {% end %}
        {% end %}
      end

      # Adds callbacks for `created_at` and `updated_at` fields
      macro with_timestamps(created_at = true, updated_at = true)
        {% if created_at %}
          before_save :__update_updated_at

          # Sets `created_at` to current time
          def __update_created_at
            @created_at = Jennifer::Config.local_time_zone.now
          end
        {% end %}

        {% if updated_at %}
          before_create :__update_created_at

          # Sets `updated_at` to current time
          def __update_updated_at
            @updated_at = Jennifer::Config.local_time_zone.now
          end
        {% end %}
      end

      # Acceptable keys:
      # - type
      # - getter
      # - setter
      # - null
      # - primary
      # - virtual
      private macro single_mapping(properties, strict = true)
        {%
          primary = nil
          primary_auto_incrementable = false
          add_default_constructor = true
        %}

        # generates hash with options
        {% for key, plain_value in properties %}
          {% value = nil %}
          {% if plain_value.is_a?(Path) && Jennifer::Macros::TYPES.includes?(plain_value.stringify) %}
            {% value = plain_value.resolve %}
            {% properties[key] = value %}
          {% else %}
            {% value = plain_value %}
          {% end %}
          {% unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
            {% properties[key] = {type: value} %}
          {% end %}
          {% properties[key][:stringified_type] = properties[key][:type].stringify %}
          {% if properties[key][:stringified_type] == Jennifer::Macros::PRIMARY_32 || properties[key][:stringified_type] == Jennifer::Macros::PRIMARY_64 %}
            {% properties[key][:primary] = true %}
          {% end %}
          {% if properties[key][:primary] %}
            {%
              primary = key
              primary_type = properties[key][:type]
              primary_auto_incrementable = Jennifer::Macros::AUTOINCREMENTABLE_STR_TYPES.includes?(properties[key][:stringified_type])
            %}
          {% end %}
          {% if properties[key][:stringified_type] =~ Jennifer::Macros::NILLABLE_REGEXP %}
            {%
              properties[key][:null] = true
              properties[key][:parsed_type] = properties[key][:stringified_type]
            %}
          {% else %}
            {% properties[key][:parsed_type] = properties[key][:null] || properties[key][:primary] ? properties[key][:stringified_type] + "?" : properties[key][:stringified_type] %}
          {% end %}
          {% add_default_constructor = add_default_constructor && (properties[key][:primary] || properties[key][:null] || properties[key].keys.includes?(:default)) %}
        {% end %}

        {% nonvirtual_attrs = properties.keys.select { |attr| !properties[attr][:virtual] } %}

        # TODO: find way to allow model definition without any primary field
        {% if primary == nil %}
          {% raise "Model #{@type} has no defined primary field. For now model without primary field is not allowed" %}
        {% end %}

        __field_declaration({{properties}}, {{primary_auto_incrementable}})

        # Returns if primary field is autoincrementable
        def self.primary_auto_incrementable?
          {{primary_auto_incrementable}}
        end

        # Returns field count
        def self.field_count
          {{properties.size}}
        end

        COLUMNS_METADATA = {{properties}}
        FIELD_NAMES = [{{properties.keys.map { |e| "#{e.id.stringify}" }.join(", ").id}}]

        # Returns array of field names
        def self.field_names
          FIELD_NAMES
        end

        # Returns named tuple of column metadata
        def self.columns_tuple
          COLUMNS_METADATA
        end

        @new_record = true
        @destroyed = false

        # Creates object from `DB::ResultSet`
        def initialize(%pull : DB::ResultSet)
          @new_record = false
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(%pull)
        end

        # Accepts symbol hash or named tuple, stringify it and calls constructor with string-based keys hash.
        # TODO: check how converting affects performance
        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          initialize(stringify_hash(values, Jennifer::DBAny))
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny))
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        def initialize(values : Hash | NamedTuple, @new_record)
          initialize(values)
        end

        {% if add_default_constructor %}
          WITH_DEFAULT_CONSTRUCTOR = true
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

          # Default builder method
          def self.build
            o = new
            o.__after_initialize_callback
            o
          end
        {% else %}
          WITH_DEFAULT_CONSTRUCTOR = false
        {% end %}

        # Converts String based hash to `Hash(String, Jennifer::DBAny)`
        def self.build_params(hash : Hash(String, String?)) : Hash(String, Jennifer::DBAny)
          converted_hash = {} of String => Jennifer::DBAny
          hash.each do |key, value|
            case key.to_s
            {% for field, opts in properties %}
            when {{field.id.stringify}}
              if value.nil? || value.empty?
                converted_hash[key] = nil
              else
                converted_hash[key] = parameter_converter.parse(value, {{opts[:stringified_type]}})
              end
            {% end %}
            end
          end
          converted_hash
        end

        # Extracts arguments due to mapping from *pull* and returns tuple for
        # fields assignment. It stands on that fact result set has all defined fields in a row
        # TODO: think about moving it to class scope
        # NOTE: don't use it manually - there is some dependencies on caller such as reading result set to the end
        # if exception was raised
        def _extract_attributes(pull : DB::ResultSet)
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
              when {{(value[:column_name] || key).id.stringify}}
                %found{key.id} = true
                begin
                  %var{key.id} = pull.read({{value[:parsed_type].id}})
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
                raise ::Jennifer::BaseException.new("Column {{@type}}.{{key.id}} hasn't been found in the result set.")
              end
            {% end %}
          {% end %}
          {% if properties.size > 1 %}
            {
            {% for key, value in properties %}
              begin
                res = %var{key.id}.as({{value[:parsed_type].id}})
                !res.is_a?(Time) ? res : ::Jennifer::Config.local_time_zone.utc_to_local(res)
              rescue e : Exception
                raise ::Jennifer::DataTypeCasting.build({{key.id.stringify}}, {{@type}}, e)
              end,
            {% end %}
            }
          {% else %}
            {% key = properties.keys[0] %}
            begin
              %var{key}.as({{properties[key][:parsed_type].id}})
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.build({{key.id.stringify}}, {{@type}}, e)
            end
          {% end %}
        end

        def _extract_attributes(values : Hash(String, ::Jennifer::DBAny))
          {% for key, value in properties %}
            %var{key.id} = {{value[:default]}}
            %found{key.id} = true
          {% end %}

          {% for key, value in properties %}
            {% column = (value[:column_name] || key).id.stringify %}
            if values.has_key?({{column}})
              %var{key.id} = values[{{column}}]
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
              %casted_var{key.id} = !%casted_var{key.id}.is_a?(Time) ? %casted_var{key.id} : ::Jennifer::Config.local_time_zone.utc_to_local(%casted_var{key.id})
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
            {% key = properties.keys[0] %}
            %casted_var{key}
          {% end %}
        end

        # Deletes object from db and calls callbacks
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

        # Returns if any field was changed. If field again got first value - `true` anyway
        # will be returned.
        def changed?
          {% for attr in nonvirtual_attrs %}
            @{{attr.id}}_changed ||
          {% end %}
          false
        end

        # Returns hash with all attributes and symbol keys.
        def to_h
          {
            {% for key in nonvirtual_attrs %}
              :{{key.id}} => @{{key.id}},
            {% end %}
          } of Symbol => ::Jennifer::DBAny
        end

        # Returns hash with all attributes and string keys
        def to_str_h
          {
            {% for key in nonvirtual_attrs %}
              {{key.stringify}} => @{{key.id}},
            {% end %}
          } of String => ::Jennifer::DBAny
        end

        # Sets given *values* to proper fields and stores them directly to db without
        # any validation or callback
        def update_columns(values : Hash(String | Symbol, Jennifer::DBAny))
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
              raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}")
            end
          end

          self.class.adapter.update(self)
          __refresh_changes
        end

        # Sets *name* field with *value*
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

        # Returns field by given name. If object has no such field - will raise `BaseException`.
        # To avoid raising exception set `raise_exception` to `false`.
        def attribute(name : String, raise_exception : Bool = true)
          case name
          {% for attr in properties.keys %}
          when "{{attr.id}}"
            @{{attr.id}}
          {% end %}
          else
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}") if raise_exception
          end
        end

        # Returns named tuple of all fields should be saved (because they are changed).
        def arguments_to_save
          args = [] of ::Jennifer::DBAny
          fields = [] of String
          {% for attr, options in properties %}
            {% unless options[:primary] || options[:virtual] %}
              if @{{attr.id}}_changed
                args << {% if options[:stringified_type] =~ Jennifer::Macros::JSON_REGEXP %}
                          @{{attr.id}}.to_json
                        {% else %}
                          @{{attr.id}}
                        {% end %}
                fields << "{{attr.id}}"
              end
            {% end %}
          {% end %}
          {args: args, fields: fields}
        end

        def arguments_to_insert
          args = [] of ::Jennifer::DBAny
          # TODO: think about moving this array to constant; maybe use compile time instead of runtime
          fields = [] of String
          {% for attr, options in properties %}
            {% unless options[:virtual] || options[:primary] && primary_auto_incrementable %}
              args << {% if options[:stringified_type] =~ Jennifer::Macros::JSON_REGEXP %}
                        (@{{attr.id}} ? @{{attr.id}}.to_json : nil)
                      {% else %}
                        @{{attr.id}}
                      {% end %}
              fields << "{{attr.id}}"
            {% end %}
          {% end %}
          {args: args, fields: fields}
        end

        private def __refresh_changes
          {% for attr in nonvirtual_attrs %}
            @{{attr.id}}_changed = false
          {% end %}
        end

        private def init_attributes(values : Hash)
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        private def init_attributes(values : DB::ResultSet)
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
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
          MODEL = true
        end
      end

      macro mapping(properties, strict = true)
        {% if !@type.constant("MODEL") %}
          single_mapping({{properties}}, {{strict}})
        {% else %}
          sti_mapping({{properties}})
        {% end %}
      end

      macro mapping(**properties)
        mapping({{properties}})
      end
    end
  end
end
