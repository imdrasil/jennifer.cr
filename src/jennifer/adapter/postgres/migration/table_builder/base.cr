module Jennifer
  module Postgres
    module Migration
      module TableBuilder
        abstract class Base < Jennifer::Migration::TableBuilder::Base
          def adapter
            @adapter.as(Postgres::Adapter)
          end

          def schema_processor
            @adapter.schema_processor.as(SchemaProcessor)
          end
        end
      end
    end
  end
end
