module Jennifer
  module View
    # Module with mapping macros for views.
    #
    # Heavily uses `Model::Mapping`.
    module Mapping
      include Model::Mapping

      # :nodoc:
      macro __field_declaration(properties, primary_auto_incrementable)
        {% for key, value in properties %}
          @{{key.id}} : {{value[:parsed_type].id}}

          {% if value[:setter] != false %}
            def {{key.id}}=(value : {{value[:parsed_type].id}})
              @{{key.id}} = value
            end
          {% end %}

          {% if value[:getter] != false %}
            def {{key.id}}
              @{{key.id}}
            end

            {% resolved_type = value[:type].resolve %}
            {% if resolved_type == Bool || (resolved_type.union? && resolved_type.union_types[0] == Bool) %}
              def {{key.id}}?
                {{key.id}} == true
              end
            {% end %}

            def {{key.id}}!
              {{key.id}}.not_nil!
            end
          {% end %}

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
              {{key.stringify}}
            end
          {% end %}
        {% end %}
      end

      # :nodoc:
      macro base_mapping(strict = true)
        common_mapping({{strict}})

        {%
          primary = COLUMNS_METADATA.keys.find { |field| COLUMNS_METADATA[field][:primary] }
          raise "View #{@type} has no defined primary field. For now a view without a primary field is not supported" if !primary
        %}

        # Extracts arguments due to mapping from *pull* and returns tuple for fields assignment.
        # It stands on that fact result set has all defined fields in a raw
        # NOTE: don't use it manually - there is some dependencies on caller such as reading result set to the end
        # if exception was raised
        private def _extract_attributes(pull : DB::ResultSet)
          {% for key in COLUMNS_METADATA.keys %}
            %var{key.id} = nil
            %found{key.id} = false
          {% end %}
          own_attributes = self.class.actual_table_field_count
          pull.each_column do |column|
            break if own_attributes == 0

            case column
            {% for key, value in COLUMNS_METADATA %}
              when "{{key.id}}"{% if key.id.stringify != value[:column] %}, {{value[:column]}} {% end %}
                own_attributes -= 1
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
            else
              {% if strict %}
                raise ::Jennifer::BaseException.new("Undefined column #{column} for model {{@type}}.")
              {% else %}
                pull.read
              {% end %}
            end
          end
          pull.read_to_end
          {% if strict %}
            {% for key, value in COLUMNS_METADATA %}
              unless %found{key.id}
                raise ::Jennifer::BaseException.new("Column #{{{@type}}}.{{value[:column].id}} hasn't been found in the result set.")
              end
            {% end %}
          {% end %}
          {% if COLUMNS_METADATA.size > 1 %}
            {
            {% for key, value in COLUMNS_METADATA %}
              begin
                res = %var{key.id}.as({{value[:parsed_type].id}})
              rescue e : Exception
                raise ::Jennifer::DataTypeCasting.build({{value[:column]}}, {{@type}}, e)
              end,
            {% end %}
            }
          {% else %}
            {% key = COLUMNS_METADATA.keys[0] %}
            begin
              %var{key}.as({{COLUMNS_METADATA[key][:parsed_type].id}})
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.build({{COLUMNS_METADATA[key][:column]}}, {{@type}}, e)
            end
          {% end %}
        end

        # Extracts attributes from given hash to the tuple. If hash has no some field - will not raise any error.
        private def _extract_attributes(values : Hash(String, AttrType))
          {% for key in COLUMNS_METADATA.keys %}
            %var{key.id} = nil
            %found{key.id} = true
          {% end %}

          {% for key, value in COLUMNS_METADATA %}
            {% column1 = key.id.stringify %}
            {% column2 = value[:column] %}
            if values.has_key?({{column1}})
              %var{key.id} =
                {% if value[:converter] %}
                  {{value[:converter]}}.from_hash(values, {{column1}}, self.class.columns_tuple[:{{key.id}}])
                {% else %}
                  values[{{column1}}]
                {% end %}
            elsif values.has_key?({{column2}})
              %var{key.id} =
                {% if value[:converter] %}
                  {{value[:converter]}}.from_hash(values, {{column2}}, self.class.columns_tuple[:{{key.id}}])
                {% else %}
                  values[{{column2}}]
                {% end %}
            else
              %found{key.id} = false
            end
          {% end %}

          {% for key, value in COLUMNS_METADATA %}
            begin
              %casted_var{key.id} =
                {% if value[:default] != nil %}
                  %found{key.id} ? %var{key.id}.as({{value[:parsed_type].id}}) : {{value[:default]}}
                {% else %}
                  %var{key.id}.as({{value[:parsed_type].id}})
                {% end %}
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.match?(e) ? ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) : e
            end
          {% end %}

          {% if COLUMNS_METADATA.size > 1 %}
            {
            {% for key, value in COLUMNS_METADATA %}
              %casted_var{key.id},
            {% end %}
            }
          {% else %}
            %casted_var{COLUMNS_METADATA.keys[0]}
          {% end %}
        end
      end
    end
  end
end
