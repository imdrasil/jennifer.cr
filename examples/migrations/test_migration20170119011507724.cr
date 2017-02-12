class TestMigration20170119011507724 < Jennifer::Migration::Base
  def up
    create(:addresses) do |t|
      t.integer :contact_id, {:null => true}
      t.string :street
      t.bool :main, {:default => false}
    end
  end

  def down
    drop :addresses
  end
end
