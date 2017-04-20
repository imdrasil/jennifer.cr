class SQLite3::ResultSet
  def column_index
    @column_index
  end

  def current_column
    columns[column_index]
  end

  def current_column_name
    column_name(column_index)
  end
end
