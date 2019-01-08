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
      end
    end
  end
end
