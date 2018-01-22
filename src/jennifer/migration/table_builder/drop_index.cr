module Jennifer
  module Migration
    module TableBuilder
      class DropIndex < Base
        def initialize(adapter, name, @index_name : String)
          super(adapter, name)
        end

        def process
          schema_processor.drop_index(@name, @index_name)
        end
      end
    end
  end
end
