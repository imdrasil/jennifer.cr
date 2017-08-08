require "../adapter"
require "./base_sql_generator"

module Jennifer
  module Adapter
    class SqlGenerator < BaseSqlGenerator
      extend SqlNotation
    end
  end
end
