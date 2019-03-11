module Jennifer
  module QueryBuilder
    module Aggregations
      def count : Int32
        adapter.count(self)
      end

      def max(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot be used with grouping") unless @groups.empty?
        group_max(field, klass)[0]
      end

      def min(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot be used with grouping") unless @groups.empty?
        group_min(field, klass)[0]
      end

      def sum(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot be used with grouping") unless @groups.empty?
        group_sum(field, klass)[0]
      end

      def avg(field, klass : T.class) : T forall T
        raise ArgumentError.new("Cannot be used with grouping") unless @groups.empty?
        group_avg(field, klass)[0]
      end

      def group_max(field, klass : T.class) : Array(T) forall T
        old_select = @raw_select
        @raw_select = "MAX(#{field}) as m"
        result = to_a.map(&.["m"])
        @raw_select = old_select
        Ifrit.typed_array_cast(result, T)
      end

      def group_min(field, klass : T.class) : Array(T) forall T
        old_select = @raw_select
        @raw_select = "MIN(#{field}) as m"
        result = to_a.map(&.["m"])
        @raw_select = old_select
        Ifrit.typed_array_cast(result, T)
      end

      def group_sum(field, klass : T.class) : Array(T) forall T
        old_select = @raw_select
        @raw_select = "SUM(#{field}) as s"
        result = to_a.map(&.["s"])
        @raw_select = old_select
        Ifrit.typed_array_cast(result, T)
      end

      def group_avg(field, klass : T.class) : Array(T) forall T
        old_select = @raw_select
        @raw_select = "AVG(#{field}) as a"
        result = to_a.map(&.["a"])
        @raw_select = old_select
        Ifrit.typed_array_cast(result, T)
      end

      def group_count(field)
        old_select = @raw_select
        @raw_select = "COUNT(#{field}) as c"
        result = to_a.map(&.["c"])
        @raw_select = old_select
        result
      end
    end
  end
end
