class CreateArticles < Jennifer::Migration::Base
  def up
    create_table :articles do |t|
      t.string :title, {:null => false}
      t.text :text

      t.reference :author

      t.timestamps
    end
  end

  def down
    drop_foreign_key :articles, :authors if foreign_key_exists? :articles, :authors
    drop_table :articles if table_exists? :articles
  end
end
