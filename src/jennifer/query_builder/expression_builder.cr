module Jennifer
  module QueryBuilder
    # Stands for creating criteria for the query.
    #
    # This class provides straight forward way to define criteria and a bit (pretty huge one)
    # of metaprogramming.
    #
    # You can use standard method `#c` to create criteria for current table or for any other (passing it's name
    # as a 2nd argument):
    #
    # ```
    # Jennifer::Query["contacts"].join("addresses") { c("contact_id") == c("id", "contacts") }
    # ```
    #
    # Also you can use "*magic*" underscored methods to specify current table fields putting "_" before a name:
    #
    # ```
    # Jennifer::Query["contacts"].join("addresses") { _contact_id == c("id", "contacts") }
    # ```
    #
    # Obviously, you also can specify same way table name for the field. Just put "__" (double underscore) between table name
    # and field name as well.
    #
    # ```
    # Jennifer::Query["contacts"].join("addresses") { _contact_id == _contacts__id }
    # ```
    #
    # Because of double underscore between symbols between field and table you can safely reference tables with "_".
    #
    # ```
    # Jennifer::Query["facebook_profiles"].join("addresses") { _profile_id == _facebook_profiles__id }
    # ```
    class ExpressionBuilder
      property query : Query?

      getter table : String, relation : String?

      def_clone

      def initialize(@table, @relation = nil, @query = nil)
      end

      # Initialize object copy;
      protected def initialize_copy(other : ExpressionBuilder)
        @table = other.@table.clone
        @relation = other.@relation.clone
        @query = other.@query
      end

      # Query's model primary field criterion.
      #
      # Can be used only in a scope of `IModelQuery`.
      def primary
        query.not_nil!.as(IModelQuery).model_class.primary
      end

      # Adds plain query *query* with filtered arguments *args*.
      #
      # If you need to wrap query set *use_brackets* to `true`.
      def sql(query : String, args : Array(DBAny) = [] of DBAny, use_brackets : Bool = true)
        RawSql.new(query, args, use_brackets)
      end

      # Adds plain query *query*.
      #
      # If you need to wrap query set *use_brackets* to `true`.
      def sql(query : String, use_brackets : Bool = true)
        RawSql.new(query, use_brackets)
      end

      # Creates criterion for current table by given name *name*.
      def c(name : String)
        Criteria.new(name, @table, @relation)
      end

      def c(name : String, table_name : String? = nil, relation : String? = nil)
        if @query
          @query.not_nil!.with_relation!
        end
        Criteria.new(name, table_name || @table, relation || @relation)
      end

      # Creates criterion by given name *name* for relation *relation*.
      def c_with_relation(name : String, relation : String)
        if @query
          @query.not_nil!.with_relation!
        end
        Criteria.new(name, @table, relation)
      end

      # Creates grouping for the given *condition*.
      def g(condition)
        Grouping.new(condition)
      end

      def group(condition)
        g(condition)
      end

      def any(query : Query)
        Any.new(query)
      end

      def all(query : Query)
        All.new(query)
      end

      def star(table : String = @table)
        Star.new(table)
      end

      def values(field : String | Symbol)
        Values.new(field)
      end

      # Combines given *first_condition*, *second_condition* and all other *conditions* by `AND` operator.
      #
      # All given conditions will be wrapped in `Grouping`.
      #
      # ```
      # User.all.where { and(_name.like("%on"), _age > 3) }
      # # WHERE (users.name LIKE '%on' AND users.age > 3)
      # ```
      def and(first_condition, second_condition, *conditions)
        g(
          conditions.reduce(first_condition & second_condition) { |sum, e| sum &= e }
        )
      end

      # Combines given *first_condition*, *second_condition* and all other *conditions* by `OR` operator.
      #
      # All given conditions will be wrapped in `Grouping`.
      #
      # ```
      # User.all.where { or(_name.like("%on"), _age > 3) }
      # # WHERE (users.name LIKE '%on' OR users.age > 3)
      def or(first_condition, second_condition, *conditions)
        g(
          conditions.reduce(first_condition | second_condition) { |sum, e| sum |= e }
        )
      end

      # Combines given *first_condition*, *second_condition* and all other *conditions* by `XOR` operator.
      #
      # All given conditions will be wrapped in `Grouping`.
      #
      # ```
      # User.all.where { xor(_name.like("%on"), _age > 3) }
      # # WHERE (users.name LIKE '%on' XOR users.age > 3)
      def xor(first_condition, second_condition, *conditions)
        g(
          conditions.reduce(first_condition.xor second_condition) { |sum, e| sum.xor e }
        )
      end

      macro method_missing(call)
        {% method_name = call.name.stringify %}
        {% if method_name.starts_with?("__") %}
          # :nodoc:
          def {{method_name.id}}
            eb = ExpressionBuilder.new(@table, {{method_name[2..-1]}}, @query)
            @query.not_nil!.with_relation! if @query
            with eb yield
          end
        {% elsif method_name.starts_with?("_") %}
          # :nodoc:
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
