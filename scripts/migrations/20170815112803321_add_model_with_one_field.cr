class AddModelWithOneField20170815112803321 < Jennifer::Migration::Base
  def up
    create_table(:one_field_models, false) do |t|
      t.integer :id, {:primary => true, :auto_increment => true}
    end
  end

  def down
    drop_table(:one_field_models)
  end
end
