module Jennifer
  module Relation
    abstract class IRelation
      extend Ifrit

      abstract def table_name
      abstract def model_class
      abstract def join_query
      abstract def condition_clause
      abstract def condition_clause(a)
      abstract def join_condition(a, b)
      abstract def query(a)
      abstract def insert(a, b)

      def join_table!
        @join_table.not_nil!
      end
    end

    class Base(T, Q) < IRelation
      getter join_query : QueryBuilder::Condition | QueryBuilder::LogicOperator?
      getter foreign : String?
      getter primary : String?, join_table : String?, join_foreign : String?

      @name : String

      def initialize(@name, foreign : String | Symbol?, primary : String | Symbol?, @join_table, _join_foreign, query)
        @join_foreign = _join_foreign.to_s if _join_foreign
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
        tree = T.c(_foreign, @name) == Q.c(_primary)
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def condition_clause(id)
        tree = T.c(foreign_field) == id
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def join_condition(query, type)
        this = self
        query.join(model_class, type: type, relation: @name) do |eb|
          this.condition_clause.not_nil!
        end
      end

      def query(primary_value)
        condition = condition_clause(primary_value)
        T.where { condition }
      end

      def insert(obj : Q, rel : Hash(String, Jennifer::DBAny))
        rel[foreign_field] = obj.attribute(primary_field)
        T.create!(rel)
      end

      def insert(obj : Q, rel : Hash(Symbol, Jennifer::DBAny))
        insert(obj, stringify_hash(rel, Jennifer::DBAny))
      end

      def insert(obj : Q, rel : T)
        rel.set_attribute(foreign_field, obj.attribute(primary_field))
        rel.save!
        rel
      end

      def remove(obj : Q, rel : T)
        rel.update_column(foreign_field, nil) if rel.attribute(foreign_field) == obj.attribute(primary_field)
        rel
      end

      def table_name
        T.table_name
      end

      def join_table_foreign_key
        @join_foreign || T.to_s.foreign_key
      end

      def foreign_field
        @foreign ||= Q.singular_table_name + "_id"
      end

      def primary_field
        @primary ||= Q.primary_field_name
      end
    end
  end
end
