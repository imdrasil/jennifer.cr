module Jennifer
  module Migration
    module TableBuilder
      class CreateEnum < Base
        def initialize(name, @values : Array(String))
          super(name)
          @adapter = Adapter.adapter.as(Adapter::Postgres)
        end

        def process
          @adapter.define_enum(@name, @values)
        end
      end
    end
  end
end
