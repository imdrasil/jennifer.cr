# :nodoc:
class PG::ResultSet
  getter column_index
  @fields : Array(PQ::Field)?

  @column_index = -1

  def current_column
    columns[@column_index]
  end

  def current_column_name
    column_name(@column_index)
  end

  def columns
    @fields.not_nil!
  end
end
