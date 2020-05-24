module Jennifer
  module Migration
    module TableBuilder
      class CreateView < Base
        @query : QueryBuilder::Query

        def initialize(adapter, name, @query)
          initialize(adapter, name)
        end

        def process
          schema_processor.create_view(@name, @query)
        end

        def explain
          "create_view :#{@name}, \"#{@query.as_sql(adapter.sql_generator)}\""
        end
      end
    end
  end
end
