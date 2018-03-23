module Jennifer
  module QueryBuilder
    class JSONSelector < Criteria
      getter path : Int32 | String, type : Symbol

      def_clone

      def initialize(criteria : Criteria, @path, @type)
        initialize(criteria.field, criteria.table, criteria.relation)
      end

      def as_sql(generator)
        generator.json_path(self)
      end
    end
  end
end
