class AlterAddress20170326172700458 < Jennifer::Migration::Base
  def up
    change(:contacts) do |t|
      t.change_column(:age, :integer, {default: 0})
      t.add_column(:description, :text)
      t.add_index("contacts_description_index", :description, type: :uniq, order: :asc, length: 10)
    end

    change(:addresses) do |t|
      t.add_column(:details, :json)
    end
  end

  def down
    change(:contacts) do |t|
      t.drop_column(:description)
    end

    change(:addresses) do |t|
      t.drop_column(:details)
    end
  end
end
