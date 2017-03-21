class DB::ResultSet
  getter column_index

  @column_index = 0
  @columns = [] of MySql::ColumnSpec

  def current_column
    @columns[@column_index]
  end

  def current_column_name
    column_name(@column_index)
  end

  def columns
    @columns
  end
end
