# :nodoc:
abstract class DB::ResultSet
  def read_to_end
    while column_index < column_count
      read
    end
  end

  abstract def current_column_name
end
