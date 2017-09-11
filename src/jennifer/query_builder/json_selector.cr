module Jennifer
  module QueryBuilder
    class Criteria
    end

    class JSONSelector < Criteria
      getter path : Int32 | String, type : Symbol

      def initialize(criteria : Criteria, @path, @type)
        initialize(criteria.field, criteria.table, criteria.relation)
      end

      def as_sql
        Adapter::SqlGenerator.json_path(self)
      end
    end
  end
end
