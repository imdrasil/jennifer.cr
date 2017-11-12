module Jennifer
  module Migration
    module TableBuilder
      class DropEnum < Base
        def initialize(name)
          super(name)
          @adapter = Adapter.adapter.as(Postgres::Adapter)
        end

        def process
          @adapter.drop_enum(@name)
        end
      end
    end
  end
end
