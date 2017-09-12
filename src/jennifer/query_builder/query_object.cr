module Jennifer
  module QueryBuilder
    abstract struct QueryObject
      getter relation : ::Jennifer::QueryBuilder::IModelQuery, params : Array(Jennifer::DBAny)

      def initialize(@relation)
        @params = [] of Jennifer::DBAny
      end

      def initialize(@relation, *options)
        @params = Ifrit.typed_array_cast(options, Jennifer::DBAny)
      end

      abstract def call
    end
  end
end
