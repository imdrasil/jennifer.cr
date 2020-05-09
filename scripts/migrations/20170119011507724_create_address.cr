class CreateAddress20170119011507724 < Jennifer::Migration::Base
  def up
    create_table(:addresses) do |t|
      t.reference :contact
      t.string :street
      t.bool :main, {:default => false}

      t.timestamps
    end
  end

  def down
    drop_foreign_key :addresses, :contacts
    drop_table :addresses
  end
end
