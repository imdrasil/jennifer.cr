module Jennifer
  module Migration
    module TableBuilder
      class CreateView < Base
        @query : QueryBuilder::Query

        def initialize(name, @query)
          initialize(name)
        end

        # TODO: move query generating to SqlGenerator class and make
        # table builder classes to call executions by themselves
        def process
          Adapter.adapter.create_view(@name, @query)
        end
      end
    end
  end
end
