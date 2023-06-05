class CreateProfile20170407022844409 < Jennifer::Migration::Base
  def up
    create_table(:profiles) do |t|
      t.bigint :contact_id
      t.string :type, {:null => false}
      t.string :uid
      t.string :login
      t.string :email
    end
  end

  def down
    drop_table(:profiles)
  end
end
