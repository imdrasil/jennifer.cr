module Jennifer
  module Model
    abstract class IRelation
      include Support

      abstract def table_name
      abstract def model_class
      abstract def join_query
      abstract def type
      abstract def condition_clause
      abstract def condition_clause(a)
    end

    class Relation(T, Q) < IRelation
      getter type : Symbol
      getter join_query : QueryBuilder::Query(T)
      getter foreign : String?
      getter primary : String?

      @name : String

      def initialize(@name, @type, foreign : String | Symbol | Nil, primary : String | Symbol | Nil, @join_query)
        @foreign = foreign.to_s if foreign
        @primary = primary.to_s if primary
      end

      def model_class
        T
      end

      def condition_clause
        _foreign = foreign_field
        _primary = primary_field
        if @type != :belongs_to
          @join_query.where { T.c(_foreign) == Q.c(_primary) }
        else
          @join_query.where { Q.c(_primary) == T.c(_foreign) }
        end.tree
      end

      def condition_clause(id)
        _id = id
        if @type != :belongs_to
          _foreign = foreign_field
          @join_query.where { T.c(_foreign) == _id }
        else
          _primary = primary_field
          @join_query.where { Q.c(_primary) == _id }
        end
      end

      def table_name
        T.table_name
      end

      private def foreign_field
        @foreign || singularize(Q.table_name) + "_id"
      end

      private def primary_field
        @primary || Q.primary_field_name
      end
    end
  end
end
