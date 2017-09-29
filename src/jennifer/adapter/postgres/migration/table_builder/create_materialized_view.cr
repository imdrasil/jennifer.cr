# NOTE: WIP
module Jennifer
  module Migration
    module TableBuilder
      class CreateMaterializedView < Base
        def initialize(name, @as : String)
          super(name)
        end

        def process
          query = <<-SQL
            CREATE MATERIALIZED VIEW #{name}
            AS #{@as}
          SQL
          adapter.exec(query)
        end
      end
    end
  end
end
