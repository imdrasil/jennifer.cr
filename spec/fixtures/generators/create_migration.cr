class CreatePublicArticles < Jennifer::Migration::Base
  def up
    create_table :public_articles do |t|
      t.string :title, {:null => false}
      t.text :text

      t.timestamps
    end
  end

  def down
    drop_table :public_articles if table_exists? :public_articles
  end
end
