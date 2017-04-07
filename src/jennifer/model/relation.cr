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
      getter join_query : QueryBuilder::Criteria | QueryBuilder::LogicOperator?
      getter foreign : String?
      getter primary : String?

      @name : String

      def initialize(@name, @type, foreign : String | Symbol?, primary : String | Symbol?, query)
        @foreign = foreign.to_s if foreign
        @primary = primary.to_s if primary
        @join_query = query.tree
        @join_query.not_nil!.set_relation(T.table_name, @name) if @join_query
      end

      def model_class
        T
      end

      def condition_clause
        _foreign = foreign_field
        _primary = primary_field
        tree = if @type != :belongs_to
                 T.c(_foreign, @name) == Q.c(_primary)
               else
                 T.c(_primary, @name) == Q.c(_foreign)
               end
        @join_query ? tree & @join_query.not_nil!.dup : tree
      end

      def condition_clause(id)
        tree = if @type != :belongs_to
                 T.c(foreign_field) == id
               else
                 T.c(primary_field) == id
               end
        @join_query ? tree & @join_query.not_nil!.dup : tree
      end

      def table_name
        T.table_name
      end

      private def foreign_field
        @foreign || (@type != :belongs_to ? Q : T).singular_table_name + "_id"
      end

      private def primary_field
        @primary || (@type != :belongs_to ? Q : T).primary_field_name
      end
    end
  end
end
