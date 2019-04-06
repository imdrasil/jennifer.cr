module Jennifer
  module Migration
    module TableBuilder
      class DropTable < Base
        def process
          schema_processor.drop_table(self)
        end

        def explain
          "drop_table :#{@name}"
        end
      end
    end
  end
end
