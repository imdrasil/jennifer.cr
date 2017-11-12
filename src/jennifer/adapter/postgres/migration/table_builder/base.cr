module Jennifer
  module Postgres
    module Migration
      module TableBuilder
        abstract class Base < Jennifer::Migration::TableBuilder::Base
          def adapter
            @adapter.as(Postgres::Adapter)
          end
        end
      end
    end
  end
end
