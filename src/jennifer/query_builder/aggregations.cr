module Jennifer
  module QueryBuilder
    # Contains aggregation query functions.
    module Aggregations
      # Returns result row count in `Int64`.
      #
      # ```
      # Jennifer::Query["contacts"].count # => 123
      # ```
      def count : Int64
        adapter.count(self)
      end

      # Returns maximum value of the field *field* of type *klass*.
      #
      # *field* is pasted **as is** into the query. Also `ArgumentError` is raised if any grouping
      # is already specified.
      #
      # ```
      # Jennifer::Query["contacts"].max("age", Int32) # => 45
      # ```
      def max(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot be used with grouping") if _groups?
        group_max(field, klass)[0]
      end

      # Returns minimum value of the field *field* of type *klass*.
      #
      # *field* is pasted **as is** into the query. Also `ArgumentError` is raised if any grouping
      # is already specified.
      #
      # ```
      # Jennifer::Query["contacts"].min("age", Int32) # => 18
      # ```
      def min(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot be used with grouping") if _groups?
        group_min(field, klass)[0]
      end

      # Returns sum of the field *field* of type *klass*.
      #
      # *field* is pasted **as is** into the query. Also `ArgumentError` is raised if any grouping
      # is already specified.
      #
      # ```
      # # for MySQL
      # Jennifer::Query["contacts"].sum("age", Float64) # => 1000.0
      # # for PostgreSQL
      # Jennifer::Query["contacts"].sum("age", Int64) # => 1000i64
      # ```
      def sum(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot be used with grouping") if _groups?
        group_sum(field, klass)[0]
      end

      # Returns average value of the field *field* of type *klass*.
      #
      # *field* is pasted **as is** into the query. Also `ArgumentError` is raised if any grouping
      # is already specified.
      #
      # ```
      # # for MySQL
      # Jennifer::Query["contacts"].avg("age", Float64) # => 17.5
      # # for PostgreSQL
      # Jennifer::Query["contacts"].avg("age", PG::Numeric) # => 17.5 of PG::Numeric
      # ```
      def avg(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot be used with grouping") if _groups?
        group_avg(field, klass)[0]
      end

      # Returns array of counts values of the field *field* of type *klass* in groups.
      #
      # *field* is pasted **as is** into the query.
      #
      # ```
      # Jennifer::Query["contacts"].group(:city_id).group_count("age", Int32) # => [45, 39]
      # ```
      def group_count(field)
        old_select = @raw_select
        @raw_select = "COUNT(#{field}) as c"
        result = to_a.map(&.["c"])
        @raw_select = old_select
        result
      end

      # Returns array of maximum values of the field *field* of type *klass* in groups.
      #
      # *field* is pasted **as is** into the query.
      #
      # ```
      # Jennifer::Query["contacts"].group(:city_id).group_max("age", Int32) # => [45, 39]
      # ```
      def group_max(field, klass : T.class) : Array(T) forall T
        old_select = @raw_select
        @raw_select = "MAX(#{field}) as m"
        result = to_a.map(&.["m"])
        @raw_select = old_select
        Ifrit.typed_array_cast(result, T)
      end

      # Returns array of minimum values of the field *field* of type *klass* in groups.
      #
      # *field* is pasted **as is** into the query.
      #
      # ```
      # Jennifer::Query["contacts"].group(:city_id).group_min("age", Int32) # => [45, 39]
      # ```
      def group_min(field, klass : T.class) : Array(T) forall T
        old_select = @raw_select
        @raw_select = "MIN(#{field}) as m"
        result = to_a.map(&.["m"])
        @raw_select = old_select
        Ifrit.typed_array_cast(result, T)
      end

      # Returns array of values sums of the field *field* of type *klass* in groups.
      #
      # *field* is pasted **as is** into the query.
      #
      # ```
      # # MySQL
      # Jennifer::Query["contacts"].group(:city_id).group_sum("age", Float64) # => [45.0, 39.0]
      # # PostgreSQL
      # Jennifer::Query["contacts"].group(:city_id).group_sum("age", Int64) # => [45, 39] of Int64
      # ```
      def group_sum(field, klass : T.class) : Array(T) forall T
        old_select = @raw_select
        @raw_select = "SUM(#{field}) as s"
        result = to_a.map(&.["s"])
        @raw_select = old_select
        Ifrit.typed_array_cast(result, T)
      end

      # Returns array of average values of the field *field* of type *klass* in groups.
      #
      # *field* is pasted **as is** into the query.
      #
      # ```
      # # MySQL
      # Jennifer::Query["contacts"].group(:city_id).group_avg("age", Float64) # => [45.0, 39.0]
      # # PostgreSQL
      # Jennifer::Query["contacts"].group(:city_id).group_avg("age", PG::Numeric) # => [45.0, 39.0] of PG::Numeric
      # ```
      def group_avg(field, klass : T.class) : Array(T) forall T
        old_select = @raw_select
        @raw_select = "AVG(#{field}) as a"
        result = to_a.map(&.["a"])
        @raw_select = old_select
        Ifrit.typed_array_cast(result, T)
      end
    end
  end
end
