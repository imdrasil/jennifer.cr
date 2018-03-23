require "./query_builder/sql_node"

module Jennifer
  module QueryBuilder
    class Criteria < SQLNode
    end

    class Grouping < SQLNode
    end
  end
end

require "./query_builder/logic_operator"
require "./query_builder/*"
