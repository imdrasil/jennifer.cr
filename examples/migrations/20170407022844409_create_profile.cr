class CreateProfile20170407022844409 < Jennifer::Migration::Base
  def up
    create_table(:profiles) do |t|
      t.integer :contact_id, {:null => true}
      t.string :type
      t.string :uid, {:null => true}
      t.string :login
      t.string :email, {:null => true}
    end
  end

  def down
    drop_table(:profiles)
  end
end
