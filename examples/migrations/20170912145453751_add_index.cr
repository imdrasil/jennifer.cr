class AddIndex20170912145453751 < Jennifer::Migration::Base
  def up
    change_table(:addresses) do |t|
      t.add_index "addresses_street_index", [:street], :uniq
    end
  end

  def down
    change_table(:countries) do |t|
      t.drop_index "addresses_street_index"
    end
  end
end
