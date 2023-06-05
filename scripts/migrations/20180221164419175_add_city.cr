class AddCity20180221164419175 < Jennifer::Migration::Base
  def up
    create_table :cities do |t|
      t.string :name, {:null => false}
      t.bigint :country_id, {:null => false}
      t.integer :optimistic_lock, {:default => 0}
    end
  end

  def down
    drop_table :cities
  end
end
