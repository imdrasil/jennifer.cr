module Jennifer
  module Postgres
    module Migration
      module TableBuilder
        class DropMaterializedView < Jennifer::Migration::TableBuilder::Base
          def initialize(adapter, name)
            super(adapter, name)
          end

          def process
            adapter.exec "DROP MATERIALIZED VIEW #{name}"
          end

          def explain
            "drop_materialized_view :#{@name}"
          end
        end
      end
    end
  end
end
