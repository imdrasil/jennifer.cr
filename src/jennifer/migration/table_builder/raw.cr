module Jennifer
  module Migration
    module TableBuilder
      class Raw < Base
        getter raw_sql

        def initialize(query : String)
          super("")
          @raw_sql = query
        end

        def process
          Adapter.adapter.exec(@raw_sql)
        end
      end
    end
  end
end
