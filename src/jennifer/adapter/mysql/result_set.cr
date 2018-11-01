# :nodoc:
module MySql
  class ResultSet
    getter column_index, columns

    @column_index = 0

    def current_column
      @columns[@column_index]
    end

    def current_column_name
      column_name(@column_index)
    end
  end

  class TextResultSet
    getter column_index, columns

    @column_index = 0

    def current_column
      @columns[@column_index]
    end

    def current_column_name
      column_name(@column_index)
    end
  end
end
