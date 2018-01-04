module Jennifer
  module Migration
    module TableBuilder
      class DropTable < Base
        def process
          schema_processor.drop_table(self)
        end
      end
    end
  end
end
