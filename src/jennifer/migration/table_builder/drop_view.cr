module Jennifer
  module Migration
    module TableBuilder
      class DropView < Base
        def process
          migration_processor.drop_view(@name)
        end
      end
    end
  end
end
