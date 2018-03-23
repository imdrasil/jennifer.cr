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
    refresh_male_contacts_view
  end

  def down
    drop_table :users
    change_table(:contacts) do |t|
      t.drop_column :user_id
    end
    refresh_male_contacts_view
  end

  private def refresh_male_contacts_view
    drop_view(:male_contacts)
    create_view(:male_contacts, Jennifer::Query["contacts"].where { sql("gender = 'male'") })
  end
end
