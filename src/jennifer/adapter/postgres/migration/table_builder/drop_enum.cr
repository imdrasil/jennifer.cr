module Jennifer
  module Postgres
    module Migration
      module TableBuilder
        class DropEnum < Jennifer::Migration::TableBuilder::Base
          def initialize(adapter, name)
            super(adapter, name)
          end

          def process
            schema_processor.drop_enum(@name)
          end

          def explain
            "drop_enum :#{@name}"
          end
        end
      end
    end
  end
end
