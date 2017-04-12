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
    end
  end
end
