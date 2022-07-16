module Jennifer
  module QueryBuilder
    class OrderExpression < SQLNode
      # Sorting direction
      enum Direction
        ASC
        DESC
      end

      # Specifies position of `null` values in the ordered collection.
      enum NullPosition
        NONE
        LAST
        FIRST
      end

      getter criteria : Criteria, direction : Direction, null_position : NullPosition

      def initialize(@criteria : Criteria, @direction, @null_position = NullPosition::NONE)
        @criteria.as(RawSql).without_brackets if @criteria.is_a?(RawSql)
      end

      def_clone

      protected def initialize_copy(other)
        @criteria = other.@criteria.clone
        @direction = other.@direction.dup
        @null_position = other.@null_position.dup
      end

      def ==(other : OrderExpression)
        eql?(other)
      end

      def eql?(other : OrderExpression)
        criteria.eql?(other.criteria) &&
          direction == other.direction &&
          null_position == other.null_position
      end

      # Specify sorting direction by `String` or `Symbol` analogue.
      def direction=(value : Symbol | String)
        @direction = Direction.parse(value.to_s)
      end

      # Reverse sorting order.
      #
      # `null` position isn't affected.
      def reverse
        @direction = @direction.asc? ? Direction::DESC : Direction::ASC
        self
      end

      def nulls_last
        @null_position = NullPosition::LAST
        self
      end

      def nulls_first
        @null_position = NullPosition::FIRST
        self
      end

      def nulls_unordered
        @null_position = NullPosition::NONE
        self
      end

      def as_sql(generator)
        generator.order_expression(self)
      end

      def sql_args : Array(DBAny)
        @criteria.sql_args
      end

      def filterable?
        @criteria.filterable?
      end

      def set_relation(table, name)
        @criteria.set_relation(table, name)
      end

      def alias_tables(aliases)
        @criteria.alias_tables(aliases)
      end

      def change_table(old_name, new_name)
        @criteria.change_table(old_name, new_name)
      end
    end
  end
end
