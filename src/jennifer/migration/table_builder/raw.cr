module Jennifer
  module Migration
    module TableBuilder
      class Raw < Base
        getter raw_sql

        def initialize(adapter, query : String)
          super(adapter, "")
          @raw_sql = query
        end

        def process
          adapter.exec(@raw_sql)
        end

        def explain
          "exec \"#{@raw_sql}\""
        end
      end
    end
  end
end
