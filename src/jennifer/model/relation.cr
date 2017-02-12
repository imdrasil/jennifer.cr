module Jennifer
  module Model
    abstract class IRelation
      abstract def table_name
      abstract def model_class
      abstract def type
    end

    class Relation(T, Q) < IRelation
      getter type

      def initialize(@name : String, @type : Symbol)
      end

      def model_class
        T
      end

      def table_name
        T.table_name
      end
    end
  end
end
