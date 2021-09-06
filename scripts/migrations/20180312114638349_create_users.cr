class CreateUsers < Jennifer::Migration::Base
  def up
    create_table(:users) do |t|
      t.string :email, {:null => false}
      t.string :password_digest, {:null => false}
      t.string :name
    end

    change_table(:contacts) do |t|
      t.add_column :user_id, :integer
    end
    drop_view(:male_contacts)
    create_view(:male_contacts, Jennifer::Query["contacts"].where { sql("gender = 'male'") })
  end

  def down
    drop_view(:male_contacts)
    drop_table :users
    change_table(:contacts) do |t|
      t.drop_column :user_id
    end
    create_view(:male_contacts, Jennifer::Query["contacts"].where { sql("gender = 'male'") })
  end
end
