class ModelWithOneField20170815112803321 < Jennifer::Migration::Base
  def up
    create_table(:one_field_models) do |t|
    end
  end

  def down
    drop_table(:one_field_models)
  end
end
