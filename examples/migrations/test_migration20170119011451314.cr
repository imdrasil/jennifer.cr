class TestMigration20170119011451314 < Jennifer::Migration::Base
  def up
    create(:contacts) do |t|
      t.string :name, {:size => 30}
      t.integer :age
    end
  end

  def down
    drop :contacts
  end
end
