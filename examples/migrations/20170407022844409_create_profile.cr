class CreateProfile20170407022844409 < Jennifer::Migration::Base
  def up
    create(:profiles) do |t|
      t.integer :contact_id, {:null => true}
      t.string :type
      t.string :uid, {:null => true}
      t.string :login
      t.string :email, {:null => true}
    end
  end

  def down
    drop(:profiles)
  end
end
