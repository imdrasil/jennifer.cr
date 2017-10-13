module Jennifer
  module QueryBuilder
    module Joining
      def join(source : Class, aliass : String? = nil, type = :inner, relation : String? = nil)
        eb = ExpressionBuilder.new(source.table_name, relation, self)
        with_relation! if relation
        other = with eb yield eb
        add_join(Join.new(source.table_name, other, type, relation: relation))
        self
      end

      def join(source : String, aliass : String? = nil, type = :inner, relation : String? = nil)
        eb = ExpressionBuilder.new(source, relation, self)
        with_relation! if relation
        other = with eb yield eb
        add_join(Join.new(source, other, type, relation))
        self
      end

      # NOTE: aliass with passing source as a query is mandatory and will be passed to expression builder as table name
      def join(source : Query, aliass : String, type = :inner)
        eb = ExpressionBuilder.new(aliass, nil, self)
        other = with eb yield eb
        add_join(Join.new(source, other, type, nil))
        self
      end

      def lateral_join(source : Query, aliass : String? = nil, type = :inner, relation : String? = nil)
        eb = ExpressionBuilder.new(aliass, nil, self)
        other = with eb yield eb
        add_join(LateralJoin.new(source, other, type, nil))
        self
      end

      def left_join(source : Class, aliass : String? = nil)
        join(source, aliass, :left) { |eb| with eb yield }
      end

      def left_join(source : String, aliass : String? = nil)
        join(source, aliass, :left) { |eb| with eb yield }
      end

      def right_join(source : Class, aliass : String? = nil)
        join(source, aliass, :right) { |eb| with eb yield }
      end

      def right_join(source : String)
        join(source, aliass, :left) { |eb| with eb yield }
      end

      protected def add_join(value : Join)
        @joins ||= [] of Join
        @joins.not_nil! << value
      end
    end
  end
end
