module Jennifer
  module Migration
    module TableBuilder
      class DropView < Base
        def process
          adapter.drop_view(@name)
        end
      end
    end
  end
end
