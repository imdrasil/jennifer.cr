require "./field_declaration"
require "./common_mapping"

module Jennifer
  module Model
    # Contains macros to define model mapping.
    #
    # To define model mapping use `.mapping` macro. It accepts hash, tuple and splatted tuple,
    # where keys are model attributes (they reflects column names but this can be overided) and values -
    # mapping properties. Mapping value can be `Class`, `HashLiteral`, `NamedTupleLiteral` or constant
    # that can be resolved as `HashLiteral` or `NamedTupleLiteral`.
    #
    # Available mapping properties:
    #
    # * `:type` - data type class (e.g. `Int32`);
    # * `:primary` - whether field is primary - at least one file of a model must be primary;
    # * `:null` - whether field is nillable; another way to define this is specify `type` as union with
    # the second `Nil` (e.g. `Int32?`);
    # * `:default` - attribute default value that is assigned when new object is created and no value
    # is specified;
    # * `:column` - database column name associated with this attribute (default is attribute name);
    # * `:getter` - whether attribute reader should be generated (`true` by default);
    # * `:setter` - whether attribute writer should be generated (`true` by default);
    # * `:virtual` - whether attribute is virtual (will not be stored to / retrieved from database);
    # * `:converter` - class to be used to serialize/deserialize data.
    # * `:auto` - mark primary key as autoincrementable - it's value will be assigned by database automatically
    # (`true` for `Int32` & `Int64`)
    #
    # ```
    # class Contact < Jennifer::Model::Base
    #   with_timestamps
    #   mapping(
    #     id: Primary32, # same as { type: Int32, primary: true }
    #     name: String,
    #     gender: { type: String? },
    #     age: { type: Int32, default: 10 },
    #     description: String?,
    #     created_at: Time?,
    #     updated_at: Time | Nil
    #   )
    # end
    # ```
    #
    # ### Mapping type
    #
    # Constants used as a `:type` value and presents subset of mapping properties are called **mapping type**.
    # To use them you should firstly register it
    #
    # ```
    # class ApplicationRecord < Jennifer::Model::Base
    #   EmptyString = {
    #     type: String,
    #     default: ""
    #   }
    #
    #   {% TYPES << "EmptyString" %}
    #   # or if this is outside of model or view scope
    #   {% ::Jennifer::Macros::TYPES << "EmptyString" %}
    # end
    # ```
    #
    # For more details about exiting mapping types see `Macros` and `Authentication`.
    #
    # ### Inheritance
    #
    # Mapping also can be specified in abstract super class to be shared with all subclass models
    #
    # ```
    # class ApplicationRecord < Jennifer::Model::Base
    #   mapping(
    #     id: Primary32
    #   )
    # end
    #
    # class User < ApplicationRecord
    #   mapping(
    #     name: String
    #   )
    # end
    # ```
    #
    # Or inside of a module
    #
    # ```
    # module SharedMapping
    #   include Jennifer::Model::Mapping
    #
    #   mapping(
    #     id: Primary32
    #   )
    # end
    #
    # class User < Jennifer::Model::Base
    #   include SharedMapping
    #
    #   mapping(
    #     email: String
    #   )
    # end
    # ```
    #
    # `.mapping` can be used only once per module/class definition. If class has no field to be added after
    # inheritance or module inclusion - place `.mapping` without any argument.
    #
    # ### STI
    #
    # For single table inheritance just define define parent non-abstract class with all common fields and
    # `type: String` extra field and inherit from it. Any class inherited from non-abstract model automatically
    # behaves in scope of "single table inheritance".
    #
    # ```
    # class Profile < Jennifer::Model::Base
    #   mapping(
    #     id: Primary32,
    #     login: String,
    #     contact_id: Int32?,
    #     type: String,
    #     virtual_parent_field: {type: String?, virtual: true}
    #   )
    # end
    #
    # class FacebookProfile < Profile
    #   mapping(
    #     uid: String?, # for testing purposes
    #     virtual_child_field: {type: Int32?, virtual: true}
    #   )
    # end
    # ```
    module Mapping
      include FieldDeclaration
      include CommonMapping

      # :nodoc:
      macro copy_properties
        {%
          properties = COLUMNS_METADATA
          @type.constant("INHERITED_COLUMNS_METADATA").to_a.reduce(properties) do |hash, (key, value)|
            hash[key] = value if hash[key] == nil
            hash
          end
        %}
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

            if options[:primary] && options[:auto] != false
              options[:auto] = AUTOINCREMENTABLE_STR_TYPES.includes?(stringified_type)
            end

            hash
          end
        %}

        # :nodoc:
        COLUMNS_METADATA = { {{new_props.map { |field, mapping| "#{field}: #{mapping}" }.join(", ").id}} }
      end

      # Adds callbacks for `created_at` and `updated_at` fields.
      #
      # ```
      # class MyModel < Jennifer::Model::Base
      #   with_timestamps
      #
      #   mapping(
      #     id: { type: Int32, primary: true },
      #     created_at: { type: Time, null: true },
      #     updated_at: { type: Time, null: true }
      #   )
      # end
      # ```
      macro with_timestamps(created_at = true, updated_at = true)
        {% if created_at %}
          before_save :__update_updated_at

          # :nodoc:
          def __update_created_at
            @created_at = Time.local(Jennifer::Config.local_time_zone)
          end
        {% end %}

        {% if updated_at %}
          before_create :__update_created_at

          # :nodoc:
          def __update_updated_at
            @updated_at = Time.local(Jennifer::Config.local_time_zone)
          end
        {% end %}
      end

      # :nodoc:
      macro module_mapping
        __field_declaration({{COLUMNS_METADATA}}, false)
        copy_properties
      end

      # :nodoc:
      macro base_mapping(strict = true)
        common_mapping({{strict}})

        {%
          primary = COLUMNS_METADATA.keys.find { |field| COLUMNS_METADATA[field][:primary] }
          add_default_constructor = COLUMNS_METADATA.keys.all? do |field|
            options = COLUMNS_METADATA[field]

            options[:primary] || options[:null] || options.keys.includes?(:default.id)
          end
          properties = COLUMNS_METADATA
          nonvirtual_attrs = properties.keys.select { |attr| !properties[attr][:virtual] }
          raise "Model #{@type} has no defined primary field. For now a model without a primary field is not supported" if !primary
        %}

        # :nodoc:
        WITH_DEFAULT_CONSTRUCTOR = {{!!add_default_constructor}}

        # :nodoc:
        def self.primary_auto_incrementable?
          {{COLUMNS_METADATA[primary][:auto]}}
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

        def destroy : Bool
          return false if new_record?
          result =
            unless self.class.write_adapter.under_transaction?
              self.class.transaction do
                destroy_without_transaction
              end
            else
              destroy_without_transaction
            end
          if result
            self.class.write_adapter.subscribe_on_commit(->__after_destroy_commit_callback) if HAS_DESTROY_COMMIT_CALLBACK
            self.class.write_adapter.subscribe_on_rollback(->__after_destroy_rollback_callback) if HAS_DESTROY_ROLLBACK_CALLBACK

            return true
          end
          false
        end

        # :nodoc:
        def changed? : Bool
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

          self.class.write_adapter.update(self)
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
            {% unless options[:virtual] || options[:primary] && options[:auto] %}
              args <<
                {% if options[:converter] %} {{options[:converter]}}.to_db(@{{attr.id}}) {% else %} @{{attr.id}} {% end %}
              fields << {{options[:column]}}
            {% end %}
          {% end %}
          {args: args, fields: fields}
        end

        # Extracts arguments due to mapping from *pull* and returns tuple for fields assignment.
        # It stands on that fact result set has all defined fields in a row
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
                  %found{key.id} ? %var{key.id}.as({{value[:parsed_type].id}}) : {{value[:default]}}
                {% else %}
                  %var{key.id}.as({{value[:parsed_type].id}})
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

          adapter = self.class.write_adapter
          if is_new_record
            adapter.subscribe_on_commit(->__after_create_commit_callback) if HAS_CREATE_COMMIT_CALLBACK
            adapter.subscribe_on_rollback(->__after_create_rollback_callback) if HAS_CREATE_ROLLBACK_CALLBACK
          else
            adapter.subscribe_on_commit(->__after_update_commit_callback) if HAS_CREATE_COMMIT_CALLBACK
            adapter.subscribe_on_rollback(->__after_update_rollback_callback) if HAS_CREATE_ROLLBACK_CALLBACK
          end
          adapter.subscribe_on_commit(->__after_save_commit_callback) if HAS_SAVE_COMMIT_CALLBACK
          adapter.subscribe_on_rollback(->__after_save_rollback_callback) if HAS_SAVE_ROLLBACK_CALLBACK
          true
        end

        macro inherited
          # :nodoc:
          MODEL = true
        end
      end

      # :nodoc:
      macro draw_mapping(strict = true)
        {% if !@type.ancestors.includes?(Reference) || @type.abstract? %}
          module_mapping
        {% elsif !@type.constant("MODEL") %}
          copy_properties
          base_mapping({{strict}})
        {% else %}
          sti_mapping
          copy_properties
        {% end %}
      end

      # Defines model mapping.
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
      #
      # For more details see `Mapping` module documentation.
      macro mapping(properties, strict = true)
        {% if properties.size > 0 %}
          build_properties({{properties}})
        {% end %}
        draw_mapping({{strict}})
      end

      # ditto
      macro mapping(**properties)
        {% if properties.size > 0 %}
          mapping({{properties}})
        {% else %}
          draw_mapping(true)
        {% end %}
      end

      # :nodoc:
      macro populate
        macro included
          populate
        end

        macro inherited
          populate
        end

        {% if @type != Jennifer::Model::Base && @type != Jennifer::View::Mapping %}
          {% metadata = @type.ancestors[0].constant("COLUMNS_METADATA") || @type.ancestors[0].constant("INHERITED_COLUMNS_METADATA") %}
          {% if @type.constant("INHERITED_COLUMNS_METADATA") == nil %}
            {% if metadata == nil %}
              # :nodoc:
              INHERITED_COLUMNS_METADATA = {} of Nil => Nil
            {% else %}
              # :nodoc:
              INHERITED_COLUMNS_METADATA = {{metadata}}
            {% end %}
          {% elsif metadata != nil %}
            {%
              metadata.to_a.reduce(INHERITED_COLUMNS_METADATA) do |hash, (key, value)|
                hash[key] = value
                hash
              end
            %}
          {% end %}
        {% end %}
      end

      macro included
        populate
      end
    end
  end
end
