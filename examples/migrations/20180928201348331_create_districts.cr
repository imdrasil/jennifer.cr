class AddDistricts20180928201348331 < Jennifer::Migration::Base
  def up
    create_table :districts do |t|
      t.string :code, { :null => false }
      t.integer :country_id, { :null => false }
    end
  end

  def down
    drop_table :districts
  end
end
