class Passport20170122152105921 < Jennifer::Migration::Base
  def up
    create(:passports, false) do |t|
      t.string(:enn, {:primary => true, :size => 5})
      t.reference(:contact)
    end
  end

  def down
    drop(:passports)
  end
end
