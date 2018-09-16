module Jennifer
  module Relation
    class PolymorphicHasOne(T, Q) < Base(T, Q)
      getter foreign_type : String

      def initialize(name, foreign, primary, query, foreign_type : String | Symbol?, inverse_of : String | Symbol)
        @foreign_type = foreign_type ? foreign_type.to_s : inverse_of.to_s + "_type"
        foreign = foreign || "#{inverse_of}_id"
        super(name, foreign, primary, query, nil)
      end

      def condition_clause
        tree = (T.c(foreign_field, @name) == Q.c(primary_field)) & (T.c(foreign_type, @name) == polymorphic_type_value)
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def condition_clause(id)
        tree = (T.c(foreign_field) == id) & (T.c(foreign_type, @name) == polymorphic_type_value)
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def condition_clause(ids : Array)
        tree = (T.c(foreign_field).in(ids)) & (T.c(foreign_type, @name) == polymorphic_type_value)
        @join_query ? tree & @join_query.not_nil!.clone : tree
      end

      def insert(obj : Q, rel : Hash(String, Jennifer::DBAny))
        rel[foreign_field] = obj.attribute(primary_field)
        rel[foreign_type] = polymorphic_type_value
        T.create!(rel)
      end

      def insert(obj : Q, rel : T)
        raise BaseException.new("Object already has one another object") unless obj.attribute(foreign_field).nil?
        rel.set_attribute(foreign_field, obj.attribute(primary_field))
        rel.set_attribute(foreign_type, polymorphic_type_value)
        rel.save!
        rel
      end

      def remove(obj : Q, rel : T)
        if rel.attribute(foreign_field) == obj.attribute(primary_field) && rel.attribute(foreign_type) == polymorphic_type_value
          rel.update_columns({ foreign_field => nil, foreign_type => nil })
        end
        rel
      end

      def polymorphic_type_value
        @polymorphic_type_value ||= Q.to_s
      end

      # TODO: find way to update exactly one record, not all
      def remove(obj : Q)
        this = self
        _pf = obj.attribute(primary_field)
        T.all.where { T.c(this.foreign_field) == _pf }.update({foreign_field => nil})
      end
    end
  end
end
