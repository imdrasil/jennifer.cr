module Jennifer
  module Migration
    module TableBuilder
      class DropView < Base
        def process
          schema_processor.drop_view(@name)
        end

        def explain
          "drop_view :#{@name}"
        end
      end
    end
  end
end
