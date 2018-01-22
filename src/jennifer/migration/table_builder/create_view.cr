module Jennifer
  module Migration
    module TableBuilder
      class CreateView < Base
        @query : QueryBuilder::Query

        def initialize(adapter, name, @query)
          initialize(adapter, name)
        end

        # TODO: move query generating to SqlGenerator class and make
        # table builder classes to call executions by themselves
        def process
          schema_processor.create_view(@name, @query)
        end
      end
    end
  end
end
