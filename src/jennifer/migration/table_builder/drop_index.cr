module Jennifer
  module Migration
    module TableBuilder
      class DropIndex < Base
        def initialize(name, @index_name : String)
          super(name)
        end

        def process
          Adapter.adapter.drop_index(@name, @index_name)
        end
      end
    end
  end
end
