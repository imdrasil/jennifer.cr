class AddJoinTable < Jennifer::Migration::Base
  def up
    create_table(:countries) do |t|
      t.string(:name)
    end
    create_join_table(:contacts, :countries)
    create_join_table(:contacts, :profiles)
  end

  def down
    drop_table(:countries)
    drop_join_table(:contacts, :countries)
    drop_join_table(:contacts, :profiles)
  end
end
