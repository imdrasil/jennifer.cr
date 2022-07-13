class CreateAddress20170119011507724 < Jennifer::Migration::Base
  def up
    create_table(:addresses, id: false) do |t|
      t.integer :id, {:primary => true, :auto_increment => true}
      t.reference :contact
      t.string :street
      t.bool :main, {:default => false}

      t.timestamps
    end
    change_table(:addresses) do |t|
      t.change_column :id, :bigint, {:auto_increment => true}
    end
  end

  def down
    drop_foreign_key :addresses, :contacts
    drop_table :addresses
  end
end
