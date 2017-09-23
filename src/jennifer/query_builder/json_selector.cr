module Jennifer
  module QueryBuilder
    class Criteria
    end

    class JSONSelector < Criteria
      getter path : Int32 | String, type : Symbol

      def_clone

      def initialize(criteria : Criteria, @path, @type)
        initialize(criteria.field, criteria.table, criteria.relation)
      end

      def as_sql
        Adapter::SqlGenerator.json_path(self)
      end

      def as_sql(io, escape = true)
        io << as_sql
      end
    end
  end
end
