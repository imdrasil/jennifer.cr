module Jennifer
  module Migration
    module TableBuilder
      class DropMaterializedView < Base
        def initialize(name)
          super(name)
        end

        def process
          adapter.exec "DROP MATERIALIZED VIEW #{name}"
        end
      end
    end
  end
end
