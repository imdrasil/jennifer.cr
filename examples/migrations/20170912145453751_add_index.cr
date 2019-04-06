class AddIndex20170912145453751 < Jennifer::Migration::Base
  def up
    change_table(:addresses) do |t|
      t.add_index [:street], :uniq
    end
  end

  def down
    change_table(:addresses) do |t|
      t.drop_index [:street]
    end
  end
end
