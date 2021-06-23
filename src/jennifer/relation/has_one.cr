module Jennifer
  module Relation
    class HasOne(T, Q) < Base(T, Q)
      def initialize(*opts)
        super
      end

      def insert(obj : Q, rel : T)
        raise BaseException.new("Object already has one another object") unless obj.attribute(foreign_field).nil?

        super
      end

      def remove(obj : Q)
        this = self
        _pf = obj.attribute_before_typecast(primary_field)
        T.all.where { T.c(this.foreign_field) == _pf }.update({foreign_field => nil})
      end
    end
  end
end
