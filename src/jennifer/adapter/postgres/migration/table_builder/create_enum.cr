module Jennifer
  module Migration
    module TableBuilder
      class CreateEnum < Base
        def initialize(name, @values : Array(String))
          super(name)
        end

        def process
          Adapter.adapter.define_enum(@name, @values)
        end
      end
    end
  end
end
