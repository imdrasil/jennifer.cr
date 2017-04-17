module Jennifer
  module Relation
    class HasMany(T, Q) < Base(T, Q)
      def initialize(*opts)
        super
      end

      def insert(obj : Q, rel : T)
        rel.set_attribute(foreign_field, obj.attribute(primary_field))
        rel.save!
        rel
      end
    end
  end
end
