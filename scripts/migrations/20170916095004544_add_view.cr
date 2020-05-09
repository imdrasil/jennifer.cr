class AddView < Jennifer::Migration::Base
  def up
    create_view(:male_contacts, Jennifer::Query["contacts"].where { _gender == sql("'male'") })
  end

  def down
    drop_view(:male_contacts)
  end
end
