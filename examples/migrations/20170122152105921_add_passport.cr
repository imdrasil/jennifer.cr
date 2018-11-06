class AddPassport < Jennifer::Migration::Base
  def up
    create_table(:passports, false) do |t|
      t.string(:enn, {:primary => true, :size => 5})
      t.reference(:contact)
    end
  end

  def down
    drop_foreign_key(:passports, :contacts)
    drop_table(:passports)
  end
end
