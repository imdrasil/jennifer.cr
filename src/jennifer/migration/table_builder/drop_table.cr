module Jennifer
  module Migration
    module TableBuilder
      class DropTable < Base
        def process
          adapter.drop_table(self)
        end
      end
    end
  end
end
