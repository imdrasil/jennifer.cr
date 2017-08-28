# NOTE: WIP
module Jennifer
  module Migration
    module TableBuilder
      class CreateMaterializedView < Base
        def initialize(name, @as : QueryBuilder::Query, @options : Hash(Symbol, Array(String)))
          super(name)
          @adapter = Adapter.adapter.as(Adapter::Postgres)
        end

        def process
          @adapter.execute <<-SQL
            CREATE MATERIALIZED VIEW #{name}
            AS #{Adapter::SqlGenerator.select(@as)}
          SQL
        end
      end
    end
  end
end
