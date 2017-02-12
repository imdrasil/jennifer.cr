class Passport20170122152105921 < Jennifer::Migration::Base
  def up
    create(:passports, false) do |t|
      t.string(:enn, {primary: true, size: 5})
      t.integer(:contact_id)
    end
  end

  def down
    drop(:passport)
  end
end
