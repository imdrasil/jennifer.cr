class AddColumnAliasModels20181017202211501 < Jennifer::Migration::Base
  def up
    create_table :authors do |t|
      t.string :first_name, {:null => false}
      t.string :last_name, {:null => false}
      {% if env("DB") == "postgres" || env("DB") == nil %}
        t.generated :full_name, :string, "first_name || ' ' || last_name", {:stored => true}
      {% else %}
        t.generated :full_name, :string, "CONCAT(first_name, ' ', last_name)", {:stored => true}
      {% end %}
    end

    {% if env("DB") == "postgres" || env("DB") == nil %}
      create_enum(:publication_type_enum, ["Book", "Article", "BlogPost"])

      create_table :publications do |t|
        t.string :title, {:null => false}
        t.integer :version, {:null => false}
        t.integer :pages
        t.string :url
        t.string :publisher
        t.field :type, :publication_type_enum
      end
    {% else %}
      create_table :publications do |t|
        t.string :title, {:null => false}
        t.integer :version, {:null => false}
        t.integer :pages
        t.string :url
        t.string :publisher
        t.enum :type, ["Book", "Article", "BlogPost"]
      end
    {% end %}

    create_join_table(:authors, :publications)

    create_view(:print_publications, Jennifer::Query["publications"].where { sql("type IN ('Book', 'Article')") })
  end

  def down
    drop_view :print_publications
    drop_join_table :authors, :publications
    drop_table :publications
    drop_enum :publication_type_enum
    drop_table :authors
  end
end
