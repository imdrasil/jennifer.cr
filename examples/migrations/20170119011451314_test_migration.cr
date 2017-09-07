class TestMigration20170119011451314 < Jennifer::Migration::Base
  def up
    {% if env("DB") == "postgres" || env("DB") == nil %}
      create_enum(:gender_enum, ["male", "female"])
      create_table(:contacts) do |t|
        t.string :name, {:size => 30}
        t.integer :age
        t.integer :tags, {:array => true}
        t.decimal :ballance
        t.field :gender, :gender_enum
        t.timestamps
      end
      change_enum(:gender_enum, {:add_values => ["unknown"]})
      change_enum(:gender_enum, {:rename_values => ["unknown", "other"]})
      change_enum(:gender_enum, {:remove_values => ["other"]})
    {% else %}
      create_table(:contacts) do |t|
        t.string :name, {:size => 30}
        t.integer :age
        t.decimal :ballance
        t.enum :gender, ["male", "female"], {:default => "male"}
        t.timestamps
      end
    {% end %}
  end

  def down
    drop_table :contacts
    drop_enum(:gender_enum)
  end
end
