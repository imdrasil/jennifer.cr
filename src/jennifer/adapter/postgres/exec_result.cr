module Jennifer
  module Adapter
    class Postgres
      struct ExecResult
        getter last_insert_id : Int64

        def initialize(@last_insert_id)
        end
      end
    end
  end
end
