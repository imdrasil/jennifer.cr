class PQ::Field
  @@table_names = {} of Int32 => String

  def table
    val = @@table_names[@col_oid]?
    if val
      val.not_nil!
    else
      @@table_names[@col_oid] = load_table_name
    end
  end

  private def load_table_name : String
    value = ""
    # TODO: decouple from adapter
    ::Jennifer::Adapter.adapter.query("select relname from pg_class where oid = $1", @col_oid) do |rs|
      rs.each do
        value = rs.read(String)
      end
    end
    raise "table not found" if value.empty?
    value
  end
end
