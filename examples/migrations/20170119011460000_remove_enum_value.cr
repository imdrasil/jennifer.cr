class RemoveEnumValue < Jennifer::Migration::Base
  def up
    {% if env("DB") == "postgres" || env("DB") == nil %}
      change_enum(:gender_enum, {:remove_values => ["other"]})
    {% end %}
  end

  def down
    {% if env("DB") == "postgres" || env("DB") == nil %}
      change_enum(:gender_enum, {:add_values => ["other"]})
    {% end %}
  end
end
