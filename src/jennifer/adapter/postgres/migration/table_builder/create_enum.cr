module Jennifer
  module Postgres
    module Migration
      module TableBuilder
        class CreateEnum < Base
          def initialize(adapter, name, @values : Array(String))
            super(adapter, name)
          end

          def process
            schema_processor.define_enum(@name, @values)
          end
        end
      end
    end
  end
end
