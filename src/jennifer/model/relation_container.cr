# WIP; just for experiment
module Jennifer
  module Model
    class IRelationContainer
    end

    class RelationContainer(T, Q) < IRelationContainer
      include Enumerable(T)

      # getter relation : Relation(T, Q), records : Array(T)

      def initialize(@relation)
        @records = [] of T
      end

      def records
        @records = @query.to_a if @records.empry?
        @records
      end

      def each
        to_a.each do |e|
          yield e
        end
      end
    end
  end
end
