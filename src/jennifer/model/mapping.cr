alias Primary32 = Int32
alias Primary64 = Int64

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
              @{{key.id}}_changed = true if _{{key.id}} != @{{key.id}}
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

            {% if primary_auto_incrementable %}
              # Inits primary field
              def init_primary_field(value)
                raise ::Jennifer::AlreadyInitialized.new(@{{key.id}}, value) if @{{key.id}}
                @{{key.id}} = value.as({{value[:type]}})
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
          @created_at = Jennifer::Config.local_time_zone.now
        end

        # Sets `updated_at` to current time
        def __update_updated_at
          @updated_at = Jennifer::Config.local_time_zone.now
        end
      end

      private macro single_mapping(properties, strict = true)
        def self.children_classes
          {% begin %}
            {% if @type.all_subclasses.size > 0 %}
              [{{ @type.all_subclasses.join(", ").id }}]
            {% else %}
              [] of Model::Base.class
            {% end %}
          {% end %}
        end

        @@strict_mapping : Bool?

        def self.strict_mapping?
          @@strict_mapping ||= adapter.table_column_count(table_name) == field_count
        end

        {%
          primary = nil
          primary_auto_incrementable = false
          add_default_constructor = true
        %}

        # generates hash with options
        {% for key, value in properties %}
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

        # Returns array of field names
        def self.field_names
          [
            {% for key in properties.keys %}
              "{{key.id}}",
            {% end %}
          ]
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

        # Accepts symbol hash or named tuple, stringify it and calls
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

        # TODO: think about next method
        # def attributes=(values : Hash)
        # end

        def self.build(pull : DB::ResultSet)
          \{% begin %}
            \{% klasses = @type.all_subclasses.select { |s| s.constant("STI") == true } %}
            \{% if !klasses.empty? %}
              hash = adapter.result_to_hash(pull)
              o =
                case hash["type"]
                when "", nil, "\{{@type}}"
                  new(hash, false)
                \{% for klass in klasses %}
                when "\{{klass}}"
                  \{{klass}}.new(hash, false)
                \{% end %}
                else
                  raise ::Jennifer::UnknownSTIType.new(self, hash["type"])
                end
            \{% else %}
              o = new(pull)
            \{% end %}

            o.__after_initialize_callback
            o
          \{% end %}
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

        # Extracts arguments due to mapping from *pull* and returns tuple for
        # fields assignment. It stands on that fact result set has all defined fields in a raw
        # TODO: think about moving it to class scope
        # NOTE: don't use it manually - there is some dependencies on caller such as reading result set to the end
        # if exception was raised
        def _extract_attributes(pull : DB::ResultSet)
          requested_columns_count = self.class.actual_table_field_count
          ::Jennifer::BaseException.assert_column_count(requested_columns_count, pull.column_count)
          {% for key, value in properties %}
            %var{key.id} = nil
            %found{key.id} = false
          {% end %}
          requested_columns_count.times do
            column = pull.column_name(pull.column_index)
            case column
            {% for key, value in properties %}
              when {{value[:column_name] || key.id.stringify}}
                %found{key.id} = true
                begin
                  %var{key.id} = pull.read({{value[:parsed_type].id}})
                rescue e : Exception
                  raise ::Jennifer::DataTypeMismatch.new(column, {{@type}}, e) if ::Jennifer::DataTypeMismatch.match?(e)
                  raise e
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
            {% for key, value in properties %}
              unless %found{key.id}
                raise ::Jennifer::BaseException.new("Column #{{{@type}}}##{{{key.id.stringify}}} hasn't been found in the result set.")
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
                raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
                raise e
              end,
            {% end %}
            }
          {% else %}
            {% key = properties.keys[0] %}
            begin
              %var{key}.as({{properties[key][:parsed_type].id}})
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
              raise e
            end
          {% end %}
        end

        def _extract_attributes(values : Hash(String, ::Jennifer::DBAny))
          {% for key, value in properties %}
            %var{key.id} = nil
            %found{key.id} = true
          {% end %}

          {% for key, value in properties %}
            if !values[{{value[:column_name] || key.id.stringify}}]?.nil?
              %var{key.id} = values[{{value[:column_name] || key.id.stringify}}]
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
              raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
              raise e
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

        def save!(skip_validation : Bool = false)
          raise Jennifer::RecordInvalid.new(errors) unless save(skip_validation)
          true
        end

        def save(skip_validation : Bool = false) : Bool
          result = 
            unless self.class.adapter.under_transaction?
              {{@type}}.transaction do
                save_without_transaction(skip_validation)
              end || false
            else
              save_without_transaction(skip_validation)
            end
          return result unless result
          # adapter.subscribe_on_commit() if HAS_COMMIT_CALLBACK
          # adapter.subscribe_on_rollback if HAS_ROLLBACK_CALLBACK
          result
        end

        # Saves all changes to db without invoking transaction; if validation not passed - returns `false`
        def save_without_transaction(skip_validation : Bool = false) : Bool
          unless skip_validation
            return false unless __before_validation_callback
            validate!
            return false unless valid?
            __after_validation_callback
          end
          return false unless __before_save_callback
          response =
            if new_record?
              return false unless __before_create_callback
              res = self.class.adapter.insert(self)
              {% if primary && primary_auto_incrementable %}
                if primary.nil? && res.last_insert_id > -1
                  init_primary_field(res.last_insert_id.to_i)
                end
              {% end %}
              @new_record = false if res.rows_affected != 0
              __after_create_callback
              self.class.adapter.subscribe_on_commit(->__after_create_commit_callback) if HAS_CREATE_COMMIT_CALLBACK
              self.class.adapter.subscribe_on_rollback(->__after_create_rollback_callback) if HAS_CREATE_ROLLBACK_CALLBACK
              res
            else
              self.class.adapter.update(self)
            end
          __after_save_callback
          self.class.adapter.subscribe_on_commit(->__after_save_commit_callback) if HAS_SAVE_COMMIT_CALLBACK
          self.class.adapter.subscribe_on_rollback(->__after_save_rollback_callback) if HAS_SAVE_ROLLBACK_CALLBACK
          response.rows_affected == 1
        end

        # Deletes object from db and calls callbacks
        def destroy
          {% begin %}
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
          {% end %}
        end

        # Reloads all fields from db.
        def reload
          raise ::Jennifer::RecordNotFound.new("It is not persisted yet") if new_record?
          this = self
          self.class.all.where { this.class.primary == this.primary }.limit(1).each_result_set do |rs|
            {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(rs)
          end
          __refresh_changes
          __refresh_relation_retrieves
          self
        end

        # Returns if any field was changed. If field again got first value - `true` anyway
        # will be returned.
        def changed?
          {% for key, value in properties %}
            @{{key.id}}_changed ||
          {% end %}
          false
        end

        # Returns hash with all attributes and symbol keys.
        def to_h
          {
            {% for key in properties.keys %}
              :{{key.id}} => @{{key.id}},
            {% end %}
          }
        end

        # Returns hash with all attributes and string keys
        def to_str_h
          {
            {% for key in properties.keys %}
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
                @{{key.id}}_changed = true
              else
                raise ::Jennifer::BaseException.new("Wrong type for #{name} : #{value.class}")
              end
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
        def attribute(name : String | Symbol, raise_exception : Bool = true)
          case name.to_s
          {% for key, value in properties %}
          when "{{key.id}}"
            @{{key.id}}
          {% end %}
          else
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}") if raise_exception
          end
        end

        def arguments_to_save
          args = [] of ::Jennifer::DBAny
          fields = [] of String
          {% for key, value in properties %}
            {% unless value[:primary] %}
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
          args = [] of ::Jennifer::DBAny
          # TODO: think about moving this array to constant; maybe use compiletime instead of runtime
          fields = [] of String
          {% for key, value in properties %}
            {% unless value[:primary] && primary_auto_incrementable %}
              args << {% if value[:stringified_type] =~ Jennifer::Macros::JSON_REGEXP %}
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

        private def __check_if_changed
          raise Jennifer::Skip.new unless changed? || new_record?
        end

        private def init_attributes(values : Hash)
          super
          {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
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
