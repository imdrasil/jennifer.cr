module Jennifer
  module Postgres
    struct ExecResult
      getter last_insert_id : Int64, rows_affected = 0i64

      def initialize(@last_insert_id)
      end

      def initialize(@last_insert_id, @rows_affected)
      end
    end
  end
end
