module Jennifer
  module Relation
    class HasMany(T, Q) < Base(T, Q)
      def initialize(*opts)
        super
      end

      def insert(obj : Q, rel : Hash(String, Jennifer::DBAny))
        rel[foreign_field] = obj.attribute(primary_field)
        T.create(rel)
      end

      def insert(obj : Q, rel : Hash(Symbol, Jennifer::DBAny))
        insert(obj, to_s_hash(rel, Jennifer::DBAny))
      end

      def insert(obj : Q, rel : T)
        if rel.new_record?
          rel.set_attribute(foreign_field, obj.attribute(primary_field))
          rel.save
        end
        rel
      end
    end
  end
end
