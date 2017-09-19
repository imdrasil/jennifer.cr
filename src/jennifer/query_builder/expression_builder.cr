module Jennifer
  module QueryBuilder
    class ExpressionBuilder
      property query : Query?

      def_clone

      def initialize(@table : String, @relation : String? = nil, @query = nil)
      end

      # Initialize object copy;
      protected def initialize_copy(other)
        @table = other.@table.clone
        @relation = other.@relation.clone
        @query = other.@query
      end

      def sql(_query : String, args = [] of DB::Any)
        RawSql.new(_query, args)
      end

      def c(name : String)
        Criteria.new(name, @table, @relation)
      end

      def c(name : String, table_name : String)
        Criteria.new(name, table_name, @relation)
      end

      def c(name : String, table_name : String, relation : String)
        @query.not_nil!.with_relation! if @query
        Criteria.new(name, table_name, relation)
      end

      macro method_missing(call)
        {% method_name = call.name.stringify %}
        {% if method_name.starts_with?("__") %}
          def {{method_name.id}}
            eb = ExpressionBuilder.new(@table, {{method_name[2..-1]}}, @query)
            @query.not_nil!.with_relation! if @query
            with eb yield
          end
        {% elsif method_name.starts_with?("_") %}
          def {{method_name.id}}
            {%
              parts = method_name[1..-1].split("__")
              table = parts[0]
              field = parts[1]
            %}
            {% if parts.size == 1 %}
              c({{table}})
            {% else %}
              {% if Reference.all_subclasses.map(&.stringify).includes?(table.camelcase) %}
                {{table.camelcase.id}}._{{field.id}}
              {% else %}
                c({{field}}, {{table}})
              {% end %}
            {% end %}
          end
        {% elsif call.name.stringify =~ /^_[_\w]*/ %}
          {% raise "Cant parse method name #{method_name}" %}
        {% end %}
      end
    end
  end
end
