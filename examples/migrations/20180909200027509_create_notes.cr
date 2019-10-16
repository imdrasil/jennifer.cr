class CreateNotes < Jennifer::Migration::Base
  with_transaction false

  def up
    create_table :notes do |t|
      t.string :text

      t.integer :notable_id
      t.string :notable_type

      t.timestamps
    end
  end

  def down
    drop_table :notes
  end
end
