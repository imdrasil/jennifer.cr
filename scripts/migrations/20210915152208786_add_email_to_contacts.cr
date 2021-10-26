class AddEmailToContacts < Jennifer::Migration::Base
  def up
    change_table :contacts do |t|
      t.add_column :email, :string
      t.add_index :email, :unique
    end
  end

  def down
    change_table :contacts do |t|
      t.drop_index :email
      t.drop_column :email
    end
  end
end
