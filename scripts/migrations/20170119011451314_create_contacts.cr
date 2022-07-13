class CreateContacts < Jennifer::Migration::Base
  def up
    {% if env("DB") == "postgres" || env("DB") == nil %}
      create_enum(:gender_enum, ["male", "female"])
      create_table(:contacts) do |t|
        t.string :name, {:size => 30}
        t.integer :age
        t.integer :tags, {:array => true}
        t.decimal :ballance, {:precision => 6, :scale => 2}
        t.field :gender, :gender_enum
        t.timestamps true
      end
      change_enum(:gender_enum, {:add_values => ["unknown"]})
      change_enum(:gender_enum, {:rename_values => ["unknown", "other"]})
    {% else %}
      create_table(:contacts) do |t|
        t.string :name, {:size => 30}
        t.integer :age
        t.decimal :ballance, {:precision => 6, :scale => 2}
        t.enum :gender, ["male", "female"], {:default => "male"}
        t.timestamps true
      end
    {% end %}
  end

  def down
    drop_table :contacts
    {% if env("DB") == "postgres" || env("DB") == nil %}
      drop_enum(:gender_enum)
    {% end %}
  end
end
