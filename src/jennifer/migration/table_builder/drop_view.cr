module Jennifer
  module Migration
    module TableBuilder
      class DropView < Base
        def process
          Adapter.adapter.drop_view(@name)
        end
      end
    end
  end
end
